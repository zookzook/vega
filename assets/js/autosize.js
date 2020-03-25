export function autoSize(inpElement, refElement) {

    let input = inpElement || document.getElementById('board_title');
    let ref = refElement || document.getElementById('board_title_ref');

    function new_width() {

        let width   = ref.offsetWidth;
        // let style   = window.getComputedStyle(ref);
        // let margin  = parseFloat(style.marginLeft) + parseFloat(style.marginRight);
        // let padding = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
        // let border  = parseFloat(style.borderLeftWidth) + parseFloat(style.borderRightWidth);
        input.style.width = width  + "px";
    }
    let update = function (e) {
        ref.innerHTML = input.value;
        new_width();
    };
    input.addEventListener('input', update);
    new_width();
}

