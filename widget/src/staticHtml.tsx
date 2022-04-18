import * as React from 'react';

export type HtmlAttribute = [string, string]

export type Html =
  { element: [string, HtmlAttribute[], Html[]] } |
  { text: string }

export function Html_toRawString(h : Html): string {
  if ('text' in h) return h.text
  else if ('element' in h) {
    const tag = h.element[0]
    const attrs = h.element[1].map(([name, val]) => `${name}="${val}"`).join(' ')
    const cs = h.element[2].map(Html_toRawString).join('')

    return `<${tag} ${attrs}>${cs}</${tag}>`
  }
  else throw `unexpected variant ${h} of Html`
}

export default function (props: { html: Html }) {
    return <span dangerouslySetInnerHTML={{__html: Html_toRawString(props.html)}}></span>;
}