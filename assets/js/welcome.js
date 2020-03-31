import css from "../css/pages/welcome.scss"
import * as bs from "./bert-serializer"
import "phoenix_html"
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

let Hooks = {};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks, decode: bs.decode});
liveSocket.connect();
