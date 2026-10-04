import UI from "./ui.mjs";
const names = Object.keys(UI);
console.log("exports:", names.length, names.filter(n => /^(measure|place|update|imap_demo|tree|state)$/.test(n)));
console.log(UI.imap_demo());
