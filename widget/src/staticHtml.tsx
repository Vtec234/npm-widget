import * as React from 'react';

export type HtmlAttribute = [string, string]

export type Html =
  { element: [string, HtmlAttribute[], Html[]] } |
  { text: string }

export function HtmlComponent(h : Html) : any {
  if ('text' in h) return h.text
  else if ('element' in h) {
    const [tag, attrs, children] = h.element
    const attrObj : {[k : string]: string}= {}
    for (const kv in attrs) {
      let [k,v] = kv
      if (k == "class") {
        attrObj["className"] = v
      }
      attrObj[k] = v
    }
    return React.createElement(tag, attrObj, children.map(HtmlComponent))
  }
  else throw `unexpected variant ${h} of Html`
}

export default function (props: { html: Html }) {
    return HtmlComponent(props.html)
}