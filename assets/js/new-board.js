import css from "../css/pages/new-board.scss"
import "phoenix_html"
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"
import * as bs from "./bert-serializer"

let Hooks = {};

Hooks.Focus = {
    mounted() {
        this.el.focus();
    },
    updated() {
        this.el.focus();
    }
};

Hooks.Color = {
    mounted() {
        this.updated();
    },
    updated() {
        let body = document.querySelector("body");
        body.className = '';
        let current = this.el.querySelector(".is-active");
        let color = current.getAttribute("phx-value-color");
        body.classList.add(color);
    }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks, decode: bs.decode});
liveSocket.connect();
