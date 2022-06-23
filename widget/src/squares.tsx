import * as React from 'react';

import { RpcSessions } from '@lean4/infoview/infoview/rpcSessions';
import { DocumentPosition, InteractiveCode, RpcContext, useAsync, CodeWithInfos } from '@lean4/infoview';
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
    return <PenroseCanvas dsl={commutativeDsl} sty={commutativeSty} sub={commutativeSquareSub} />
}

function CommTriangle({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    return <PenroseCanvas dsl={commutativeDsl} sty={commutativeSty} sub={commutativeTriangleSub} />
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
    const [status, diag, err] = useAsync(() => getCommutativeDiagram(rs, pos), [pos.uri, pos.line, pos.character])

    if (status === 'pending')
        return <>Loading...</>
    else if (status === 'rejected')
        return <>Error: {JSON.stringify(err)}</>
    else if (diag && diag.kind === 'square')
        return <CommSquare pos={pos} diag={diag} />
    else if (diag && diag.kind === 'triangle')
        return <CommTriangle pos={pos} diag={diag} />
    else console.error('Unexpected data ', diag)
}