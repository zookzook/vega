import css from "../css/pages/new-board.scss"
import "phoenix_html"
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

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
        let body = document.querySelector("body");
        body.className = '';
        body.classList.add(this.el.getAttribute("data-color"));
        this.el.getAttribute("data-color");
        console.log("X");
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
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks});
liveSocket.connect();
