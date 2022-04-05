import * as React from 'react';
import { EditorContext } from '@lean4/infoview';
import { PlotlyEg } from './plot'
import { MathComponent } from 'mathjax-react';

export default function (props: {}) {
    const ec = React.useContext(EditorContext);
    return <div><b>Hello widget!!</b>
        <button onClick={() => {
            ec.copyToComment('Comment!');
        }}>Make a comment!</button>
        <MathComponent display tex={String.raw`\int_0^1 x^2\ dx`} />
        asdf
        <PlotlyEg />
    </div>;
}
