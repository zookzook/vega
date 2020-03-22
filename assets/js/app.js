// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.scss"
import "phoenix_html"
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"
import Sortable from 'sortablejs'

let Hooks = {};

Hooks.AutoSize = {
    mounted() {
        autoSize();
    }
};

Hooks.AutoClose = {
    mounted() {
        let current = this.el.querySelector('.add-card-form--cancel');
        let cancel = document.querySelectorAll(".add-card-form--cancel");
        let n  = cancel.length;
        for (let i = 0; i < n; i++) {
            if( current != cancel[i]) {
                cancel[i].click();
            } // if
        } // for

        this.el.querySelector('textarea').focus();
    }
};

Hooks.Board = {

    mounted() {

        let self = this;
        let board = document.querySelector(".board-lists");
        let sortable = new Sortable(board, {
            handle: ".list-drag-handle",
            draggable: ".list-wrapper",
            filter: ".list-composer",
            chosenClass: "list-is-dragging",
            onClone: function (evt) {
                let origEl = evt.item;
                let content = origEl.querySelector(".list");
                content.style.opacity = "0";
                let cloneEl = evt.clone;
            },
            onEnd: function (evt) {
                let itemEl = evt.item;
                let content = itemEl.querySelector(".list");
                content.style.opacity = null;

                if(evt.oldIndex !== evt.newIndex) {

                    let lists     = board.querySelectorAll(".list-wrapper");
                    let n         = lists.length;
                    let new_order = [];
                    for (let i = 0; i < n; i++) {
                        let list = lists[i];
                        let id = list.getAttribute("id").substring(5);
                        new_order.push(id);
                    } // for
                    self.pushEvent("reorder-lists", new_order);
                } // if
            },
        });
    }
};

function autoSize() {

    let input = document.getElementById('board_title');
    let ref = document.getElementById('board_title_ref');

    function new_width() {
        let left = parseInt(window.getComputedStyle(ref, null).getPropertyValue('padding-left'), 10);
        let right = parseInt(window.getComputedStyle(ref, null).getPropertyValue('padding-right'), 10);
        let width = ref.getBoundingClientRect().width - left - right;
        input.style.width = width + "px";
    }

    let update = function (e) {
        if(e.key.length === 1) {
            ref.innerHTML = input.value + e.key;
            new_width()
        } // if
    };

    input.addEventListener('keydown', update);
    new_width();
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks});
liveSocket.connect();
