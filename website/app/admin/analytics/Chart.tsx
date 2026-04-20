"use client";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";

export default function Chart({ data }: { data: { day: string; count: number }[] }) {
  return (
    <div style={{ width: "100%", height: 300 }}>
      <ResponsiveContainer>
        <LineChart data={data}>
          <CartesianGrid stroke="#1f1f22" />
          <XAxis dataKey="day" stroke="#8a8a93" tickFormatter={(v)=>new Date(v).toLocaleDateString(undefined,{month:"short",day:"numeric"})} />
          <YAxis stroke="#8a8a93" allowDecimals={false} />
          <Tooltip contentStyle={{ background: "#111113", border: "1px solid #1f1f22" }} />
          <Line type="monotone" dataKey="count" stroke="#4f8cff" strokeWidth={2} dot={false} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
