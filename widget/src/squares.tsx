import * as React from 'react';
import * as ReactDOM from 'react-dom';

// import { RpcSessions } from '@lean4/infoview/infoview/rpcSessions';
import { DocumentPosition, InteractiveCode, useAsync, RpcContext, CodeWithInfos, RpcSessions } from '@lean4/infoview';
// TODO: can we make relative imports work? We get
// Unable to resolve specifier '@lean4/infoview/infoview/rpcInterface' imported from blob:vscode-webview://13bu9k5qafb04m5f7smuipoa2rui17ms4t3ilmibfnnsd5h3tg7k/f47b074c-568b-4501-a914-26d9a1ef1194
// import { CodeWithInfos_registerRefs } from '@lean4/infoview/infoview/rpcInterface';

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

function CommSquare({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    const [A,B,C,D] = diag.objs
    const [f,g,h,i] = diag.homs

    const mkElt = (fmt: CodeWithInfos): JSX.Element =>
        <div className="pa2">
            <InteractiveCode pos={pos} fmt={fmt} />
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
    }, [pos.uri, pos.line, pos.character, A, B, C, D, f, g, h, i])

    if (!embedNodes) return <></>
    else return <PenroseCanvas
        dsl={commutativeDsl} sty={commutativeSty} sub={commutativeSquareSub}
        embedNodes={embedNodes}
    />
}

function CommTriangle({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    const [A,B,C] = diag.objs
    const [f,g,h] = diag.homs

    const mkElt = (fmt: CodeWithInfos): JSX.Element =>
        <div className="pa2">
            <InteractiveCode pos={pos} fmt={fmt} />
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
    }, [pos.uri, pos.line, pos.character, A, B, C, f, g, h])

    if (!embedNodes) return <></>
    else return <PenroseCanvas
        dsl={commutativeDsl} sty={commutativeSty} sub={commutativeTriangleSub}
        embedNodes={embedNodes}
    />
}

function DiagramData_registerRefs(rs: RpcSessions, pos: DocumentPosition, sd: DiagramData) {
    // for (const o of sd.objs) CodeWithInfos_registerRefs(rs, pos, o)
    // for (const h of sd.homs) CodeWithInfos_registerRefs(rs, pos, h)
}

async function getCommutativeDiagram(rs: RpcSessions, pos: DocumentPosition): Promise<DiagramData | undefined> {
    const ret = await rs.call<DiagramData>(pos, 'getCommutativeDiagram', DocumentPosition.toTdpp(pos))
    if (ret) DiagramData_registerRefs(rs, pos, ret)
    return ret
}

export default function({pos}: {pos: DocumentPosition}): React.ReactNode {
    const rs = React.useContext(RpcContext)
    const [status, diag, err] = useAsync(
        () => getCommutativeDiagram(rs, pos),
        [pos.uri, pos.line, pos.character])

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
            <CommSquare pos={pos} diag={diag} />}
        {diag && diag.kind === 'triangle' &&
            <CommTriangle pos={pos} diag={diag} /> }
    </>
}
