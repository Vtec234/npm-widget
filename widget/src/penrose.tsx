import * as React from "react"
import * as ReactDOM from "react-dom"
import * as penrose from "@penrose/core"

/** See [here](https://penrose.gitbook.io/penrose/#what-makes-up-a-penrose-program) for explanation. */
interface PenroseTrio {
    dsl: string
    sty: string
    sub: string
}

/** Renders vanilla DOM `Node`s (https://filipmolcik.com/react-children-vanilla-html-element/). */
function DomElements<T>({children, ref: fwdRef}: React.PropsWithChildren<{ref?: React.Ref<T>}>) {
    // TODO: set the fwdRef here
    // TODO: maybe use a simpler DomElements, there is only one child
    return <div ref={ref => {
        if (!ref) return
        if (!children) return
        if (ref.firstChild !== null) {
            ref.replaceChild(children as any, ref.firstChild)
        } else {
            ref.appendChild(children as any)
        }
    }}></div>
}

type PenroseCanvasCoreProps = PenroseTrio &
    {maxOptSteps: number, onSvgDrawn: (_: SVGSVGElement) => void}

/** The compile -> optimize -> prepare SVG sequence is not cheap (on the order of 1s for a simple diagram),
 * so we aggressively cache its SVG outputs. */
// TODO(WN): provide a "redraw" button to resample a misshapen diagram.
const diagramSvgCache = new Map<string, SVGSVGElement>()

async function hashTrio({dsl, sty, sub}: PenroseTrio): Promise<string> {
    // https://developer.mozilla.org/en-US/docs/Web/API/TextEncoder/encodeInto#buffer_sizing
    const data = new Uint8Array(3 * (dsl.length + sty.length + sub.length))
    const encoder = new TextEncoder()
    let dataView = data
    const {written} = encoder.encodeInto(dsl, dataView)
    dataView = data.subarray(written)
    const {written: written2} = encoder.encodeInto(sty, dataView)
    dataView = data.subarray(written2)
    encoder.encodeInto(sub, dataView)
    const digest = await crypto.subtle.digest("SHA-1", data)
    const digestArr = Array.from(new Uint8Array(digest))
    // https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest#converting_a_digest_to_a_hex_string
    return digestArr.map(b => b.toString(16).padStart(2, '0')).join('')
}

async function renderPenroseTrio(trio: PenroseTrio, maxOptSteps: number): Promise<SVGSVGElement> {
    const hash = await hashTrio(trio)
    if (diagramSvgCache.has(hash)) return diagramSvgCache.get(hash)!
    const {dsl, sty, sub} = trio
    const compileRes = penrose.compileTrio({ domain: dsl, style: sty, substance: sub, variation: '' })
    if (compileRes.isErr()) throw new Error(penrose.showError(compileRes.error))
    const state = await penrose.prepareState(compileRes.value)
    const stateRes = penrose.stepUntilConvergence(state, maxOptSteps)
    if (stateRes.isErr()) throw new Error(penrose.showError(stateRes.error))
    if (!penrose.stateConverged(stateRes.value))
        console.warn(`Diagram failed to converge in ${maxOptSteps} steps`)
    const svg = await penrose.RenderStatic(stateRes.value, async path => path)
    diagramSvgCache.set(hash, svg)
    return svg
}

/** `onSvgDrawn` is called whenever a new SVG has been produced. */
function PenroseCanvasCore(
    {dsl, sty, sub, maxOptSteps, onSvgDrawn}: PenroseCanvasCoreProps)
    : JSX.Element
{
    const [canvas, setCanvas] = React.useState(<pre>Drawing..</pre>)

    const updateDiagramWithError = async (err: string) => {
        const el = <pre>Penrose error: {err}</pre>
        setCanvas(el)
    }

    const updateDiagram = async (svg: SVGSVGElement) => {
        try {
            const el = <DomElements>{svg}</DomElements>
            setCanvas(el)
            onSvgDrawn(svg)
        } catch (ex: any) {
            updateDiagramWithError(ex.toString())
        }
    }

    React.useEffect(() => {
        try {
            renderPenroseTrio({dsl, sty, sub}, maxOptSteps)
                .then(updateDiagram, ex => updateDiagramWithError(ex.toString()))
        } catch (ex: any) {
            updateDiagramWithError(ex.toString())
        }
    },
    // Note: important not to just pass `props` here so the comparison is on trio contents.
    [dsl, sty, sub, onSvgDrawn]) 

    return canvas
}

export type PenroseCanvasProps = PenroseTrio &
    {maxOptSteps: number, embedNodes: Map<string, React.ReactNode>}

/** Renders an interactive [Penrose](https://github.com/penrose/penrose) diagram with the specified trio.
 * The Penrose optimizer is ran for at most `maxOptSteps`, a heuristic for when to stop trying.
 * 
 * For every `[name, nd]` in `embedNodes` we locate an object with the same `name` in the substance
 * program, then adjust the style program so that the object's dimensions match those of `nd`,
 * and finally draw the React node `nd` over `name` in the SVG.
 * 
 * This component relies on the length of `embedNodes` never changing! If it changes,
 * you must re-create it. */
// TODO link to kc's hack https://github.com/penrose/penrose/issues/1057
// TODO: refactor this logic
export function PenroseCanvas(
        {dsl, sty, sub, maxOptSteps, embedNodes}: PenroseCanvasProps)
        : JSX.Element {
    const [containerDiv, setContainerDiv] = React.useState<HTMLDivElement | null>(null)

    interface EmbedData {
        elt: HTMLDivElement | undefined
        portal: React.ReactPortal
    }
    const [embeds, setEmbeds] = React.useState<Map<string, EmbedData>>(new Map())

    let dim = 400
    if (containerDiv) {
        const rect = containerDiv.getBoundingClientRect()
        dim = Math.ceil(Math.max(400, rect.width))
    }

    React.useEffect(() => {
        if (!embedNodes) return
        if (!containerDiv) return
        const newEmbeds: Map<string, EmbedData> = new Map()
        for (const [name, nd] of embedNodes) {
            const div = <div
                    className="dib absolute"
                    // Limit how wide nodes in the diagram can be
                    style={{maxWidth: `${Math.ceil(dim / 5)}px`}}
                    ref={newDiv => {
                        if (!newDiv) return
                        setEmbeds(embeds => {
                            const newEmbeds: Map<string, EmbedData> = new Map()
                            let changed = false
                            for (const [eName, data] of embeds) {
                                if (eName === name && data.elt !== newDiv) {
                                    changed = true
                                    newEmbeds.set(eName, {...data, elt: newDiv})
                                } else newEmbeds.set(eName, data)
                            }
                            return changed ? newEmbeds : embeds
                        })
            }}>{nd}</div>
            const portal = ReactDOM.createPortal(div, containerDiv, name)
            const data: EmbedData = {
                elt: undefined,
                portal
            }
            newEmbeds.set(name, data)
        }
        setEmbeds(newEmbeds)
    // `deps` must have constant size so we can't do a deeper comparison
    }, [embedNodes, containerDiv, dim])

    // TODO: can the canvas dynamically adjust its size to the diagram size?
    sty = sty +
`
canvas {
    width = ${dim}
    height = ${Math.ceil(dim/2)}
}
`

    const cssColourToRgba = (col: string, alpha: number = 255) => {
        if (col.startsWith('#')) {
            const gps = col.match(/\w\w/g)
            if (!gps) throw new Error(`cannot parse colour '${col}'`)
            const [r, g, b] = gps.map(x => parseInt(x, 16))
            return `rgba(${r}/255,${g}/255,${b}/255,${alpha}/255)`
        } else throw new Error(`cannot parse colour '${col}'`)
    }

    const boxCol = cssColourToRgba(
        getComputedStyle(document.documentElement)
            .getPropertyValue('--vscode-editorHoverWidget-background'))
    
    for (const [name, {elt}] of embeds) {
        if (!elt) continue
        const rect = elt.getBoundingClientRect()
        sty = sty +
`
Targettable \`${name}\` {
override \`${name}\`.textBox.width = ${Math.ceil(rect.width)}
override \`${name}\`.textBox.height = ${Math.ceil(rect.height)}
override \`${name}\`.textBox.fillColor = ${boxCol}
}
`
    }

    // Store the boxes that we can draw interactive elements over
    const [diagramBoxes, setDiagramBoxes] = React.useState<Map<string, Element>>()
    const onSvgDrawn = React.useMemo(() => {
        return (svg: SVGSVGElement) => {
            const diagramBoxes = new Map<string, Element>()
            for (const gElt of svg.querySelectorAll("g, rect")) {
                if (!gElt.textContent) continue
                const gps = gElt.textContent.match(/`(\w+)`.textBox/)
                if (!gps) continue
                const name = gps[1]
                diagramBoxes.set(name, gElt)
            }
            setDiagramBoxes(diagramBoxes)
    }}, [])

    React.useEffect(() => {
        if (!diagramBoxes) return
        if (!containerDiv) return
        for (const [name, gElt] of diagramBoxes) {
            const embed = embeds.get(name)
            if (!embed) continue
            const divElt = embed.elt
            if (!divElt) continue
            const gRect = gElt.getBoundingClientRect(),
                  containerRect = containerDiv.getBoundingClientRect()
            divElt.style.top = `${gRect.top - containerRect.top}px`
            divElt.style.left = `${gRect.left - containerRect.left}px`
        }
    }, [diagramBoxes, embeds, containerDiv])

    return <div className="relative" ref={setContainerDiv}>
        <PenroseCanvasCore dsl={dsl} sty={sty} sub={sub} maxOptSteps={maxOptSteps} onSvgDrawn={onSvgDrawn} />
        {Array.from(embeds.values()).map(({portal}) => portal)}
    </div>
}
