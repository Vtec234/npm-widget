import { LineChart, Line, XAxis, YAxis } from 'recharts';
import * as React from 'react';

export default function (props: {data, useTimer, frame_milliseconds, yDomain, xDomain}) {
    const frame_milliseconds = props.frame_milliseconds ?? 100
    const [t, setT] = React.useState(0)
    React.useEffect(() => {
        window.setTimeout(() => setT(t + 1), frame_milliseconds)
    }, [t]);

    let data : any;
    if (props.useTimer) {
        data = props.data[t % props.data.length]
    } else {
        data = props.data
    }
    // t is incrementing
    return (
        <div>
            <LineChart width={400} height={400} data={data}>
                <XAxis dataKey="x" domain={props.xDomain}/>
                <YAxis domain={props.yDomain} allowDataOverflow={true}/>
                <Line type="monotone" dataKey="y" stroke="#8884d8" dot={false}/>
            </LineChart>
            <span>time: {t}</span>
        </div>
    )
}
