import css from "../css/pages/fake-login.scss"
import "phoenix_html"
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"
import * as bs from "./bert-serializer"

let Hooks = {};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks, decode: bs.decode});
liveSocket.connect();
