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
            if(current !== cancel[i]) {
                cancel[i].click();
            } // if
        } // for

        this.el.querySelector('textarea').focus();
    }
};

Hooks.Board = {

    sortable: [],

    mounted() {

        this.init();
    },

    updated() {
        this.sortables.forEach(sortable => sortable.destroy());
        this.init();
    },

    init() {
        let self = this;
        let board = document.querySelector(".board-lists");

        this.sortables = [new Sortable(board, {
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
        })];

        let lists = document.querySelectorAll(".list-cards");
        let n  = lists.length;
        for (let i = 0; i < n; i++) {

            let s = new Sortable(lists[i], {
                draggable: ".list-card",
                chosenClass: ".ignore",
                onClone: function (evt) {
                    let origEl = evt.item;
                    let content = origEl.querySelector(".list-card-details");
                    content.style.opacity = "0";
                    origEl.classList.add('card-placeholder');
                },
                onEnd: function (evt) {
                    let itemEl = evt.item;
                    let content = itemEl.querySelector(".list-card-details");
                    content.style.opacity = null;
                    itemEl.classList.remove('card-placeholder');
                    if(evt.oldIndex !== evt.newIndex) {
                        let list_id = this.el.parentElement.parentElement.getAttribute('id').substring(5);
                        let cards = this.el.querySelectorAll(".list-card");
                        let n     = cards.length;
                        let id    = cards[evt.newIndex].getAttribute('id').substring(5);
                        if(evt.newIndex === n - 1) {
                            self.pushEvent("move-card-to-end", {id: id, list: list_id});
                        }
                        else if(evt.newIndex === 0) {
                            self.pushEvent("move-card", {id: id, before: null, list: list_id});
                        }
                        else {
                            let before_id = cards[evt.newIndex + 1].getAttribute("id").substring(5);
                            self.pushEvent("move-card", {id: id, before: before_id, list: list_id});
                        } // else
                    } // if
                },
            });

            this.sortables.push(s);
        } // for
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
