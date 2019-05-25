var player1, firstLoad = true;
var defaultkey = 'konf';
var tech = 'dash';
var file = "index.mpd",
    path, video, inputkey;
var playbtn, mutebtn, fullscreenbtn, seekSlider, curtimetext, durtimetext;

function startStream() {
    firstLoad = false;
    inputkey = document.getElementById("stream_app").value;
    if (inputkey != "") {
        key = inputkey;
    } else {
        key = defaultkey;
    }
    path = tech + "/" + key + "/" + file;

    video = document.querySelector("#dash-video-player");
    playbtn = document.getElementById("playpausebtn");
    seekSlider = document.getElementById("seekSlider");
    curtimetext = document.getElementById("curtimetext");
    durtimetext = document.getElementById("durtimetext");
    mutebtn = document.getElementById("mutebtn");
    volumeSlider = document.getElementById("volumeSlider");
    fullscreenbtn = document.getElementById("fullscreenbtn");

    // Add Events
    playbtn.addEventListener("click", playPause, false);
    seekSlider.addEventListener("change", vidSeek, false);
    video.addEventListener("timeupdate", seektimeupdate, false);
    mutebtn.addEventListener("click", vidmute, false);
    volumeSlider.addEventListener("change", setvolume, false);
    fullscreenbtn.addEventListener("click", toggleFullScreen, false);

    player1 = dashjs.MediaPlayer().create();
    player1.initialize(video, path, true);
    video.volume = 0.1
}

function switchStream(inputkey = document.getElementById("stream_app").value) {
    if (!firstLoad) {
        player1.reset();
    }
    firstLoad = false;
    if (inputkey != "") {
        key = inputkey;
    } else {
        key = defaultkey;
    }
    path = tech + "/" + key + "/" + file;
    video = document.querySelector("#dash-video-player");
    player1 = dashjs.MediaPlayer().create();
    player1.initialize(video, path, true);
}

function playPause() {
    if (video.paused) {
        video.play();
        playbtn.style.background = "url(/images/pause-button30.png) no-repeat";
    } else {
        video.pause();
        playbtn.style.background = "url(/images/play-button30.png) no-repeat";
    }

}

function vidSeek() {
    var seekto = video.duration * (seekSlider.value / 100);
    video.currentTime = seekto;
}
function seektimeupdate() {
    var nt = video.currentTime * (100 / video.duration);
    seekSlider.value = nt;
    var curmins = Math.floor(video.currentTime / 60);
    var cursecs = Math.floor(video.currentTime - curmins * 60);
    var durmins = Math.floor(video.duration / 60);
    var dursecs = Math.floor(video.duration - durmins * 60);
    if (cursecs < 10) {
        cursecs = "0" + cursecs;
    }
    if (dursecs < 10) {
        dursecs = "0" + dursecs;
    }
    if (curmins < 10) {
        curmins = "0" + curmins;
    }
    if (durmins < 10) {
        durmins = "0" + durmins;
    }
    if (durmins > 999) {
        durmins = "999";
    }

    curtimetext.innerHTML = curmins + ":" + cursecs;
    durtimetext.innerHTML = durmins + ":" + dursecs;
}

function vidmute() {
    if (video.muted) {
        video.muted = false;
        mutebtn.style.background = "url(/images/mute30.png) no-repeat";
    } else {
        video.muted = true;
        mutebtn.style.background = "url(/images/unmute30.png) no-repeat";
    }
}

function setvolume() {
    video.volume = volumeSlider.value / 100;

}

function toggleFullScreen() {
    if (video.requestFullScreen) {
        video.requestFullScreen();
    } else if (video.webkitRequestFullScreen) {
        video.webkitRequestFullScreen();
    } else if (video.mozRequestFullScreen) {
        video.mozRequestFullScreen();
    }
}

function refresh() {
    var streams;
    var button;
    var curStr = document.getElementById("otherStreams");
    streams = [ 
    ];

    while (curStr.firstChild) {
        curStr.removeChild(curStr.firstChild);
    }
    
    streams.forEach(function(button, index) {
        button = document.createElement("button");
        button.innerHTML = streams[index];
        button.setAttribute("class", "streamBtns");
        button.addEventListener('click', function () {
            switchStream(button.innerHTML);
        });
        curStr.appendChild(button)
    });
}
