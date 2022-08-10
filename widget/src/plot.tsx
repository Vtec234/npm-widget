import { LineChart, Line, XAxis, YAxis } from 'recharts';
import * as React from 'react';
const data : any = [];

for (let i = 0; i < 100; i++) {
    data.push({x: i, y: Math.sin(i / 20)})
}

export default function (props: {data}) {
    debugger;
    return (
        <LineChart width={400} height={400} data={props.data}>
            <XAxis dataKey="x"/>
            <YAxis />
            <Line type="monotone" dataKey="y" stroke="#8884d8" dot={false}/>
        </LineChart>
    )
}
