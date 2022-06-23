import * as React from 'react';

import { RpcSessions } from '@lean4/infoview/infoview/rpcSessions';
import { DocumentPosition, InteractiveCode, RpcContext } from '@lean4/infoview';
import { CodeWithInfos, CodeWithInfos_registerRefs } from '@lean4/infoview/infoview/rpcInterface';
import { useAsync } from '@lean4/infoview/infoview/util';

type DiagramKind = 'square' | 'triangle'
interface DiagramData {
    objs: CodeWithInfos[]
    homs: CodeWithInfos[]
    kind: DiagramKind
}

function CommSquare({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    const divRef = React.useRef<HTMLDivElement | null>(null)

    return <div ref={divRef}>Loading..</div>
}

function CommTriangle({pos, diag}: {pos: DocumentPosition, diag: DiagramData}): JSX.Element {
    return <div>Loading..</div> 
}

function DiagramData_registerRefs(rs: RpcSessions, pos: DocumentPosition, sd: DiagramData) {
    for (const o of sd.objs) CodeWithInfos_registerRefs(rs, pos, o)
    for (const h of sd.homs) CodeWithInfos_registerRefs(rs, pos, h)
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