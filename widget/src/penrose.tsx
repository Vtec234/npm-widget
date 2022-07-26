import * as React from "react"
import * as ReactDOM from "react-dom"
import * as penrose from "@penrose/core"
import { List } from "@svgdotjs/svg.js"

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

/** `onSvgDrawn` is called when the diagram has been drawn successfully AND is no longer updating. */
function PenroseCanvasCore(
    {dsl, sty, sub, onSvgDrawn}: PenroseTrio & {onSvgDrawn: (_: SVGSVGElement) => void})
    : JSX.Element
{
    const [canvas, setCanvas] = React.useState(<pre>Loading..</pre>)

    const updateDiagramWithError = async (err: string) => {
        const el = <pre>Penrose error: {err}</pre>
        setCanvas(el)
    }

    const updateDiagram = async (state: penrose.PenroseState) => {
        const nSteps = 500
        try {
            state = penrose.stepUntilConvergence(state, nSteps).unsafelyUnwrap()
            if (!penrose.stateConverged(state))
                console.warn(`Diagram failed to converge in ${nSteps} steps`)
            const svg = await penrose.RenderStatic(state, async path => path)
            const el = <DomElements>{svg}</DomElements>
            setCanvas(el)
            onSvgDrawn(svg)
        } catch (ex: any) {
            updateDiagramWithError(ex.toString())
        }
    }

    React.useEffect(() => {
        try {
            const compileRes = penrose.compileTrio({ domain: dsl, style: sty, substance: sub, variation: '' })
            if (compileRes.isOk()) {
                penrose.prepareState(compileRes.value)
                    .then(updateDiagram, ex => updateDiagramWithError(ex.toString()))
            } else {
                const err = penrose.showError(compileRes.error)
                updateDiagramWithError(err)
            }
        } catch (ex: any) {
            updateDiagramWithError(ex.toString())
        }
    },
    // Note: important not to just pass `props` here so the comparison is on trio contents.
    [dsl, sty, sub, onSvgDrawn]) 

    return canvas
}

/** Renders an interactive [Penrose](https://github.com/penrose/penrose) diagram with the specified trio.
 * 
 * For every `[name, nd]` in `embedNodes` we locate an object
 * with the same `name` in the substance program, then adjust the style program so that the
 * object's dimensions match those of `nd`, and finally "replace" how `name` is drawn in the SVG
 * with the React node `nd`.
 * 
 * This component relies on the length of `embedNodes` never changing! If it changes,
 * you must re-create it. */
// TODO link to kc's hack https://github.com/penrose/penrose/issues/1057
export function PenroseCanvas(
        {dsl, sty, sub, embedNodes}: PenroseTrio & {embedNodes: Map<string, React.ReactNode>})
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
        console.log("embedNodes eff", embedNodes)
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
                        console.log('div eff', newDiv)
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

    sty = sty +
`
canvas {
    width = ${dim}
    height = ${dim}
}
`

    for (const [name, {elt}] of embeds) {
        if (!elt) continue
        const rect = elt.getBoundingClientRect()
        // console.log(name, '=>', elt, '(', rect.width, 'x', rect.height, ')')
        sty = sty +
`
Targettable \`${name}\` {
override \`${name}\`.textBox.width = ${Math.ceil(rect.width)}
override \`${name}\`.textBox.height = ${Math.ceil(rect.height)}
}
`
    }

    // Store the boxes that we can draw interactive elements over
    const [diagramBoxes, setDiagramBoxes] = React.useState<Map<string, Element>>()
    const onSvgDrawn = React.useMemo(() => {
        console.log('recompute onSvgDrawn')
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
        console.log('repositioning')
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
        <PenroseCanvasCore dsl={dsl} sty={sty} sub={sub} onSvgDrawn={onSvgDrawn} />
        {Array.from(embeds.values()).map(({portal}) => portal)}
    </div>
}
