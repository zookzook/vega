// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.scss"
import "phoenix_html"
import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"
import Sortable from 'sortablejs'
import {autoSize} from './autosize'

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
        let board = document.querySelector(".board--lists");

        this.sortables = [new Sortable(board, {
            handle: ".list--drag-handle",
            draggable: ".list",
            filter: ".list--composer",
            chosenClass: "list__dragging",
            ghostClass: "list--placeholder",
            forceFallback: true,
            onEnd: function (evt) {
                if(evt.oldIndex !== evt.newIndex) {
                    let lists = board.querySelectorAll(".list");
                    let id    = lists[evt.newIndex].getAttribute('data-id');
                    if(evt.newIndex === n - 1) {
                        self.pushEvent("move-list-to-end", id);
                    } // if
                    else {
                        let before_id = lists[evt.newIndex + 1].getAttribute('data-id');
                        self.pushEvent("move-list", {id: id, before: before_id});
                    } // else
                } // if
            },
        })];

        let lists = document.querySelectorAll(".list--cards");
        let n  = lists.length;
        for (let i = 0; i < n; i++) {

            let s = new Sortable(lists[i], {
                group: 'lists',
                draggable: ".card",
                chosenClass: ".ignore",
                forceFallback: true,
                fallbackClass: "card__dragging",
                ghostClass: "card--placeholder",
                onEnd: function (evt) {
                    let to_id   = evt.to.getAttribute('data-id');
                    let from_id = evt.from.getAttribute('data-id');

                    if(evt.oldIndex !== evt.newIndex || to_id !== from_id) {
                        let cards   = evt.to.querySelectorAll(".card");
                        let n       = cards.length;
                        let id      = cards[evt.newIndex].getAttribute('data-id');
                        if(evt.newIndex === n - 1) {
                            self.pushEvent("move-card-to-end", {id: id, to: to_id, from: from_id});
                        } // if
                        else {
                            let before_id = cards[evt.newIndex + 1].getAttribute('data-id');
                            self.pushEvent("move-card", {id: id, before: before_id, to: to_id, from: from_id});
                        } // else
                    } // if

                    let cards = document.querySelectorAll(".list--cards");
                    let n = cards.length;
                    for(let i = 0; i < n; i++) {
                        cards[i].draggable = true;
                    } // for
                },
            });

            this.sortables.push(s);
        } // for
    }

};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks});
liveSocket.connect();
