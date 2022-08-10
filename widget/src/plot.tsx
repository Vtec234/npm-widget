import { LineChart, Line, XAxis, YAxis } from 'recharts';
import * as React from 'react';

export default function (props: {data}) {
    return (
        <LineChart width={400} height={400} data={props.data}>
            <XAxis dataKey="x"/>
            <YAxis />
            <Line type="monotone" dataKey="y" stroke="#8884d8" dot={false}/>
        </LineChart>
    )
}
