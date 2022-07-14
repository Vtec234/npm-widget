import * as React from "react";
import * as penrose from "@penrose/core";

/** See [here](https://penrose.gitbook.io/penrose/#what-makes-up-a-penrose-program) for explanation. */
interface PenroseTrio {
    dsl: string;
    sty: string;
    sub: string;
}

/** Renders vanilla DOM `Node`s (https://filipmolcik.com/react-children-vanilla-html-element/). */
function DomElements(props: React.PropsWithChildren<{}>) {
    return <div ref={ref => {
        if (!ref) return;
        if (!props.children) return
        if (ref.firstChild !== null) {
            ref.replaceChild(props.children as any, ref.firstChild);
        } else {
            ref.appendChild(props.children as any);
        }
    }}></div>;
}

const resolvePath: penrose.PathResolver = async (path: string) => {
    return path
}

/** Renders an interactive [Penrose](https://github.com/penrose/penrose) diagram with the specified trio.
 * 
 * When `domNodes` is non-empty, for every `(name, elt)` in `domNodes` we locate an object
 * with the same `name` in the substance program, then adjust the style program so that the
 * object's dimensions match those of `elt`, and finally "replace" how `name` is drawn in the SVG
 * with the DOM node `elt`. */
// TODO link to kc's hack https://github.com/penrose/penrose/issues/1057
export function PenroseCanvas({dsl, sty, sub, domNodes}: PenroseTrio & {domNodes?: Map<string, Element>}) {
    const el = <pre>Loading..</pre>;
    const [canvas, setCanvas] = React.useState(el);

    if (domNodes) {
        for (const [name, elt] of domNodes.entries()) {
            if (!elt) continue
            const rect = elt.getBoundingClientRect();
            console.log(name, '=>', elt, '(', rect.width, 'x', rect.height, ')');
            sty = sty +
`
Targettable \`${name}\` {
   override \`${name}\`.textBox.width = ${rect.width}
   override \`${name}\`.textBox.height = ${rect.height}
}
`
        }
    }

    const updateDiagramWithError = async (err: any) => {
        const el = <pre>Penrose error: {err.toString()}</pre>;
        setCanvas(el);
    };

    const updateDiagram = async (state: penrose.PenroseState) => {
        let i = 0;
        const maxSteps = 10;
        // TODO(WN): the convergence to interactivity is not very useful, just go with a static diagram
        do {
            try {
                const svg = await penrose.RenderStatic(state, resolvePath);
                const el = <DomElements>{svg}</DomElements>;
                setCanvas(el);

                state = penrose.stepUntilConvergence(state, 100).unsafelyUnwrap()
            } catch (ex: any) {
                updateDiagramWithError(ex.toString());
            }
            i += 1;
        } while (!penrose.stateConverged(state) && i < maxSteps);
        if (i === maxSteps) {
            updateDiagramWithError(`Diagram failed to converge in ${maxSteps*100} steps. Inconsistent constraints?`);
        } else {
            const svg = await penrose.RenderInteractive(state, updateDiagram, resolvePath);
            const el = <DomElements>{svg}</DomElements>;
            setCanvas(el);
        }
    };

    React.useEffect(() => {
        try {
            const compileRes = penrose.compileTrio({ domain: dsl, style: sty, substance: sub, variation: '' });
            if (compileRes.isOk()) {
                penrose.prepareState(compileRes.value)
                    .then(updateDiagram, updateDiagramWithError);
            } else {
                const err = penrose.showError(compileRes.error);
                updateDiagramWithError(err);
            }
        } catch (ex: any) {
            updateDiagramWithError(ex.toString());
        }
    },
    // Note: important not to just pass `props` here so the comparison is on contents.
    [dsl, sty, sub]); 

    return canvas;
}
