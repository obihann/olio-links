function toggleCollapse(event) {
    var button = event.srcElement.parentNode;
    var content = button.parentNode.nextSibling;
    var inner = content.children[0];

    if (content.style.maxHeight && content.style.maxHeight !== '0px') {
        // Currently showing, so let's hide it
        button.className = 'collapse-button';
        content.style.maxHeight = '0px';
    } else {
        // Currently hidden, so let's show it
        button.className = 'collapse-button show';
        content.style.maxHeight = inner.offsetHeight + 12 + 'px';
    }
}

// Make collapse buttons clickable
var buttons = document.querySelectorAll('.collapse-button');
for (var i = 0; i < buttons.length; i++) {
    buttons[i].onclick = toggleCollapse;

    // Show by default? Then toggle now.
    if (buttons[i].className.indexOf('show') !== -1) {
        toggleCollapse({srcElement: buttons[i].children[0]});
    }
}

window.onload = function () {
    // Remove the `preload` class to enable animations
    document.querySelector('body').className = '';
};
