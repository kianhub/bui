import M from "./ui_lib.mjs";
const list = (xs) => xs.reduceRight((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
const t0 = performance.now();
const node = M.view(M.fold(list([{ $: "Inc" }, { $: "Inc" }, { $: "Dec" }]), 10));
console.log(JSON.stringify(node), (performance.now() - t0).toFixed(3) + "ms");
console.log(Object.keys(M));
