import * as React from 'react';
import { EditorContext } from '@lean4/infoview';

export default function(props: {}) {
    const ec = React.useContext(EditorContext);
    return <div onClick={() => {
        ec.copyToComment('Comment!');
    }}><b>Hello widget!</b></div>;
}