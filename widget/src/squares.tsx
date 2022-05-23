import * as React from 'react';

import { RpcSessions } from '@lean4/infoview/infoview/rpcSessions';
import { ExprWithCtx } from '@lean4/infoview/infoview/rpcInterface';
import { DocumentPosition, InteractiveExpr, RpcContext } from '@lean4/infoview';

type DiagramKind = 'square' | 'triangle'
interface DiagramData {
    objs: ExprWithCtx[]
    homs: ExprWithCtx[]
    kind: DiagramKind
}

// https://stackoverflow.com/a/6333775
function canvas_arrow(context, fromx, fromy, tox, toy) {
    var headlen = 10; // length of head in pixels
    var dx = tox - fromx;
    var dy = toy - fromy;
    var angle = Math.atan2(dy, dx);
    context.moveTo(fromx, fromy);
    context.lineTo(tox, toy);
    context.lineTo(tox - headlen * Math.cos(angle - Math.PI / 6), toy - headlen * Math.sin(angle - Math.PI / 6));
    context.moveTo(tox, toy);
    context.lineTo(tox - headlen * Math.cos(angle + Math.PI / 6), toy - headlen * Math.sin(angle + Math.PI / 6));
}

function CommSquare({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    const canvasRef = React.useRef<HTMLCanvasElement | null>(null)
    const objRefs: React.MutableRefObject<HTMLDivElement | null>[] = []
    for (let i = 0; i < 4; i++) objRefs.push(React.useRef(null))
    const homRefs: React.MutableRefObject<HTMLDivElement | null>[] = []
    for (let i = 0; i < 4; i++) homRefs.push(React.useRef(null))

    const objBbs: DOMRect[] = []
    for (let i = 0; i < 4; i++) {
        if (!objRefs[i].current) continue
        objBbs[i] = objRefs[i].current!.getBoundingClientRect()
    }

    React.useEffect(() => {
        if (!canvasRef.current) return
        const bbCanvas = canvasRef.current.getBoundingClientRect()
        const w = bbCanvas.width, h = bbCanvas.height
        canvasRef.current.width = w
        canvasRef.current.height = h
        const ctx = canvasRef.current.getContext('2d')
        if (!ctx) return
        if (!objBbs[0] || !objBbs[1] || !objBbs[2] || !objBbs[3]) return

        const toCanvasX = (x: number) => (x - bbCanvas.x)
        const toCanvasY = (y: number) => (y - bbCanvas.y)

        ctx.clearRect(0,0,w,h)
        ctx.beginPath()
        ctx.lineWidth = 2
        ctx.lineCap = 'round'
        canvas_arrow(
            ctx,
            toCanvasX((objBbs[0].left + objBbs[0].right) / 2),
            toCanvasY(objBbs[0].bottom),
            toCanvasX((objBbs[0].left + objBbs[0].right) / 2),
            toCanvasY(objBbs[3].top)
        )

        canvas_arrow(
            ctx,
            toCanvasX((objBbs[1].left + objBbs[1].right) / 2),
            toCanvasY(objBbs[1].bottom),
            toCanvasX((objBbs[1].left + objBbs[1].right) / 2),
            toCanvasY(objBbs[2].top)
        )

        canvas_arrow(
            ctx,
            toCanvasX(objBbs[0].right), 
            toCanvasY((objBbs[0].top + objBbs[0].bottom) / 2),
            toCanvasX(objBbs[1].left),
            toCanvasY((objBbs[0].top + objBbs[0].bottom) / 2)
        )

        canvas_arrow(
            ctx,
            toCanvasX(objBbs[3].right),
            toCanvasY((objBbs[3].top + objBbs[3].bottom) / 2),
            toCanvasX(objBbs[2].left),
            toCanvasY((objBbs[3].top + objBbs[3].bottom) / 2)
        )
        ctx.stroke()
    }, [canvasRef.current, objBbs[0], objBbs[1], objBbs[2], objBbs[3]])

    return <div
        style={{
            display: 'grid',
            gridTemplateRows: 'repeat(5, auto)',
            gridTemplateColumns: 'repeat(5, auto)'
        }}
        className='relative tc'
    >
        <canvas
            className='w-100 h-100 absolute'
            style={{zIndex: -1}}
            width={1000}
            height={1000}
            ref={canvasRef}
        />
        <div ref={objRefs[0]} style={{gridRow: 2, gridColumn: 2}}>
            <InteractiveExpr pos={pos} expr={diag.objs[0]} explicit={false} />
        </div>
        <div ref={homRefs[0]} style={{gridRow: 1, gridColumn: 3}}>
            <InteractiveExpr pos={pos} expr={diag.homs[0]} explicit={false} />
        </div>
        <div ref={objRefs[1]} style={{gridRow: 2, gridColumn: 4}}>
            <InteractiveExpr pos={pos} expr={diag.objs[1]} explicit={false} />
        </div>
        <div ref={homRefs[1]} style={{gridRow: 3, gridColumn: 5}} className='tl mt5 mb5'>
            <InteractiveExpr pos={pos} expr={diag.homs[1]} explicit={false} />
        </div>
        <div ref={objRefs[2]} style={{gridRow: 4, gridColumn: 4}}>
            <InteractiveExpr pos={pos} expr={diag.objs[2]} explicit={false} />
        </div>
        <div ref={homRefs[2]} style={{gridRow: 5, gridColumn: 3}}>
            <InteractiveExpr pos={pos} expr={diag.homs[2]} explicit={false} />
        </div>
        <div ref={objRefs[3]} style={{gridRow: 4, gridColumn: 2}}>
            <InteractiveExpr pos={pos} expr={diag.objs[3]} explicit={false} />
        </div>
        <div ref={homRefs[3]} style={{gridRow: 3, gridColumn: 1}} className='tr mt5 mb5'>
            <InteractiveExpr pos={pos} expr={diag.homs[3]} explicit={false} />
        </div>
    </div>
}

function CommTriangle({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    const canvasRef = React.useRef<HTMLCanvasElement | null>(null)
    const objRefs: React.MutableRefObject<HTMLDivElement | null>[] = []
    for (let i = 0; i < 3; i++) objRefs.push(React.useRef(null))
    const homRefs: React.MutableRefObject<HTMLDivElement | null>[] = []
    for (let i = 0; i < 3; i++) homRefs.push(React.useRef(null))

    const objBbs: DOMRect[] = []
    for (let i = 0; i < 3; i++) {
        if (!objRefs[i].current) continue
        objBbs[i] = objRefs[i].current!.getBoundingClientRect()
    }

    React.useEffect(() => {
        if (!canvasRef.current) return
        const bbCanvas = canvasRef.current.getBoundingClientRect()
        const w = bbCanvas.width, h = bbCanvas.height
        canvasRef.current.width = w
        canvasRef.current.height = h
        const ctx = canvasRef.current.getContext('2d')
        if (!ctx) return
        if (!objBbs[0] || !objBbs[1] || !objBbs[2]) return

        const toCanvasX = (x: number) => (x - bbCanvas.x)
        const toCanvasY = (y: number) => (y - bbCanvas.y)

        ctx.clearRect(0,0,w,h)
        ctx.beginPath()
        ctx.lineWidth = 2
        ctx.lineCap = 'round'
        canvas_arrow(
            ctx,
            toCanvasX(objBbs[0].right), 
            toCanvasY((objBbs[0].top + objBbs[0].bottom) / 2),
            toCanvasX(objBbs[1].left),
            toCanvasY((objBbs[0].top + objBbs[0].bottom) / 2)
        )

        canvas_arrow(
            ctx,
            toCanvasX((objBbs[1].left + objBbs[1].right) / 2),
            toCanvasY(objBbs[1].bottom),
            toCanvasX((objBbs[1].left + objBbs[1].right) / 2),
            toCanvasY(objBbs[2].top)
        )

        canvas_arrow(
            ctx,
            toCanvasX(objBbs[0].right),
            toCanvasY(objBbs[0].bottom),
            toCanvasX(objBbs[2].left),
            toCanvasY(objBbs[2].top)
        )
        ctx.stroke()
    }, [canvasRef.current, objBbs[0], objBbs[1], objBbs[2], objBbs[3]])

    return <div
        style={{
            display: 'grid',
            gridTemplateRows: 'repeat(4, auto)',
            gridTemplateColumns: 'repeat(4, auto)'
        }}
        className='relative tc'
    >
        <canvas
            className='w-100 h-100 absolute'
            style={{zIndex: -1}}
            width={1000}
            height={1000}
            ref={canvasRef}
        />
        <div ref={objRefs[0]} style={{gridRow: 2, gridColumn: 1}}>
            <InteractiveExpr pos={pos} expr={diag.objs[0]} explicit={false} />
        </div>
        <div ref={homRefs[0]} style={{gridRow: 1, gridColumn: 2}}>
            <InteractiveExpr pos={pos} expr={diag.homs[0]} explicit={false} />
        </div>
        <div ref={objRefs[1]} style={{gridRow: 2, gridColumn: 3}}>
            <InteractiveExpr pos={pos} expr={diag.objs[1]} explicit={false} />
        </div>
        <div ref={homRefs[1]} style={{gridRow: 3, gridColumn: 4}} className='tl mt5 mb5'>
            <InteractiveExpr pos={pos} expr={diag.homs[1]} explicit={false} />
        </div>
        <div ref={objRefs[2]} style={{gridRow: 4, gridColumn: 3}}>
            <InteractiveExpr pos={pos} expr={diag.objs[2]} explicit={false} />
        </div>
        <div ref={homRefs[2]} style={{gridRow: 3, gridColumn: 2}} className='tl mt5 mb5'>
            <InteractiveExpr pos={pos} expr={diag.homs[2]} explicit={false} />
        </div>
    </div>
}

function DiagramData_registerRefs(rs: RpcSessions, pos: DocumentPosition, sd: DiagramData) {
    for (const o of sd.objs) {
        rs.registerRef(pos, o)
    }
    for (const h of sd.homs) {
        rs.registerRef(pos, h)
    }
}

async function getCommutativeDiagram(rs: RpcSessions, pos: DocumentPosition): Promise<DiagramData | undefined> {
    const ret = await rs.call<DiagramData>(pos, 'getCommutativeDiagram', DocumentPosition.toTdpp(pos))
    if (ret) DiagramData_registerRefs(rs, pos, ret)
    return ret
}

export default function({pos}: {pos: DocumentPosition}): React.ReactNode {
    const [diag, setDiag] = React.useState<DiagramData | undefined>()
    const rs = React.useContext(RpcContext)

    React.useEffect(() => {
        void getCommutativeDiagram(rs, pos).then(sq => {
            if (sq) setDiag(sq)
            else console.log("no square :(")
        }).catch(e => {
            console.error('Error fetchin square: ', JSON.stringify(e))
        })
    }, [pos.uri, pos.line, pos.character])

    if (diag && diag.kind === 'square')
        return <CommSquare pos={pos} diag={diag} />
    else if (diag && diag.kind === 'triangle')
        return <CommTriangle pos={pos} diag={diag} />
    else return <>Loading...</>
}