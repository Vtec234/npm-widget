import * as React from 'react';

import { Position } from 'vscode-languageserver-protocol';
import { InteractiveCode, useAsync, RpcContext, CodeWithInfos, RpcSessionAtPos, DocumentPosition } from '@lean4/infoview';

import commutativeDsl from './penrose/commutative.dsl';
import commutativeSty from './penrose/commutative.sty';
import commutativeSquareSub from './penrose/square.sub';
import commutativeTriangleSub from './penrose/triangle.sub';
import { PenroseCanvas } from './penrose';

type DiagramKind = 'square' | 'triangle'
interface DiagramData {
    objs: CodeWithInfos[]
    homs: CodeWithInfos[]
    kind: DiagramKind
}

function CommSquare({diag}: {diag: DiagramData}): JSX.Element {
    const [A,B,C,D] = diag.objs
    const [f,g,h,i] = diag.homs

    const mkElt = (fmt: CodeWithInfos): JSX.Element =>
        <div className="pa2">
            <InteractiveCode fmt={fmt} />
        </div>

    const [embedNodes, setEmbedNodes] = React.useState<Map<string, React.ReactNode>>()
    React.useEffect(() => {
        const embedNodes = new Map()
            .set("A", mkElt(A))
            .set("B", mkElt(B))
            .set("C", mkElt(C))
            .set("D", mkElt(D))
            .set("f", mkElt(f))
            .set("g", mkElt(g))
            .set("h", mkElt(h))
            .set("i", mkElt(i))
        setEmbedNodes(embedNodes)
    }, [A, B, C, D, f, g, h, i])

    if (!embedNodes) return <></>
    else return <PenroseCanvas
        dsl={commutativeDsl} sty={commutativeSty} sub={commutativeSquareSub}
        embedNodes={embedNodes}
    />
}

function CommTriangle({diag}: {diag: DiagramData}): JSX.Element {
    const [A,B,C] = diag.objs
    const [f,g,h] = diag.homs

    const mkElt = (fmt: CodeWithInfos): JSX.Element =>
        <div className="pa2">
            <InteractiveCode fmt={fmt} />
        </div>

    const [embedNodes, setEmbedNodes] = React.useState<Map<string, React.ReactNode>>()
    React.useEffect(() => {
        const embedNodes = new Map()
            .set("A", mkElt(A))
            .set("B", mkElt(B))
            .set("C", mkElt(C))
            .set("f", mkElt(f))
            .set("g", mkElt(g))
            .set("h", mkElt(h))
        setEmbedNodes(embedNodes)
    }, [A, B, C, f, g, h])

    if (!embedNodes) return <></>
    else return <PenroseCanvas
        dsl={commutativeDsl} sty={commutativeSty} sub={commutativeTriangleSub}
        embedNodes={embedNodes}
    />
}

async function getCommutativeDiagram(rs: RpcSessionAtPos, pos: Position): Promise<DiagramData | undefined> {
    return rs.call<Position, DiagramData | undefined>('getCommutativeDiagram', pos)
}

export default function({pos}: {pos: DocumentPosition}): React.ReactNode {
    const rs = React.useContext(RpcContext)
    const [status, diag, err] = useAsync(() => getCommutativeDiagram(rs, pos), [rs, pos])

    let msg = <></>
    if (status === 'pending')
        msg = <>Loading...</>
    else if (status === 'rejected')
        msg = <>Error: {JSON.stringify(err)}</>
    else if (status === 'fulfilled' && !diag)
        msg = <>No diagram.</>

    // We keep the diagrams alive to avoid a re-render when the cursor moves
    // to a position containing the same diagram.
    return <>
        {msg}
        {diag && diag.kind === 'square' &&
            <CommSquare diag={diag} />}
        {diag && diag.kind === 'triangle' &&
            <CommTriangle diag={diag} /> }
    </>
}
