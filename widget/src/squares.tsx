import * as React from 'react';
import * as ReactDOM from 'react-dom';

import * as Svg from '@svgdotjs/svg.js';

import { RpcSessions } from '@lean4/infoview/infoview/rpcSessions';
import { ExprPtr } from '@lean4/infoview/infoview/rpcInterface';
import { DocumentPosition, InteractiveExpr, RpcContext } from '@lean4/infoview';

type DiagramKind = 'square' | 'triangle'
interface DiagramData {
    objs: ExprPtr[]
    homs: ExprPtr[]
    kind: DiagramKind
}

function mkArrow(svg: Svg.Svg): Svg.G {
    const group = svg.group()
    group.path('M 20.507031 8.767563 L 20.507031 -8.369156 ')
        .fill('none')
        .stroke({
            color: 'rgb(0, 0, 0)',
            width: 0.39848,
            opacity: 1,
            linecap: 'butt',
            linejoin: 'miter',
            miterlimit: 10,
        })
    group.path('M -2.073854 2.390306 C -1.694947 0.956712 -0.851197 0.277025 0.000365 -0.00031875 C -0.851197 -0.277663 -1.694947 -0.95735 -2.073854 -2.390944 ')
        .fill('none')
        .stroke({
            color: 'rgb(0, 0, 0)',
            width: 0.39848,
            opacity: 1,
            linecap: 'round',
            linejoin: 'round',
            miterlimit: 10,
        })
    return group
}

function CommSquare({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    // const ref = React.useRef<SVGSVGElement | null>(null)
    // const [divs, setDivs] = React.useState<HTMLDivElement[]>([])
    // React.useEffect(() => {
    //     if (!ref.current) return
    //     const svg = Svg.SVG(ref.current).size(200, 200)
    //     const rect = svg.rect(100, 100).attr({fill: '#f06'})
    //     const foreign = svg.foreignObject(100, 100).size(100,100)
    //     const div = document.createElement('div')
    //     foreign.add(new Svg.Dom(div, { xmlns: 'http://www.w3.org/1999/xhtml'}))
    //     setDivs([div])
    //     const arr = mkArrow(svg).scale(2, 2)
    //     // arr.x(foreign.bbox().x2 + 5)

    // }, [ref])
    // return <>
    //     {divs.length > 0 &&
    //         ReactDOM.createPortal(<InteractiveExpr pos={pos} expr={diag.objs[0]} explicit={false}/>, divs[0])}
    //     <svg xmlns="http://www.w3.org/2000/svg" ref={ref} />
    // </>

    return <>
        Commutative square:<br/>
        objects<br/>
        <InteractiveExpr pos={pos} expr={diag.objs[0]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.objs[1]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.objs[2]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.objs[3]} explicit={false} /><br/>
        arrows<br/>
        <InteractiveExpr pos={pos} expr={diag.homs[0]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.homs[1]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.homs[2]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.homs[3]} explicit={false} /><br/>
    </>
}

function CommTriangle({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    return <>
        Commutative triangle:<br/>
        objects<br/>
        <InteractiveExpr pos={pos} expr={diag.objs[0]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.objs[1]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.objs[2]} explicit={false} /><br/>
        arrows<br/>
        <InteractiveExpr pos={pos} expr={diag.homs[0]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.homs[1]} explicit={false} /><br/>
        <InteractiveExpr pos={pos} expr={diag.homs[2]} explicit={false} /><br/>
    </>
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