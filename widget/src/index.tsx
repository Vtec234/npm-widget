import * as React from 'react';
import { EditorContext } from '@lean4/infoview';
// import { PlotlyEg } from './plot'
import { MathComponent } from 'mathjax-react';

export default function (props: { greeting: string }) {
    const ec = React.useContext(EditorContext);
    return <div>
        <p><b>{props.greeting}</b></p>
        <p>
            <button onClick={() => {
                ec.copyToComment('Comment!');
            }}>Make a comment!</button>
        </p>
        <MathComponent display tex={String.raw`\int_0^1 x^2\ dx + c`} />
        Hello everyone!
    </div>;
}
