function docButtons() {

	//ChooseButton();
	runningSim = ActiveTrains;

    SlowButton();
    StopButton();
    docInfos();
}


/////////////////////////////////////////////
function docInfos() {
	var info = L.control({ position: 'bottomleft' });

	info.onAdd = function (map) {
    	this._div = L.DomUtil.create('div', 'doc_info'); // create a div with a class "info"
    	this._div.id = "doc_info";
    	return this._div;
	};

	info.addTo(mymap);
	$('.doc_info').prepend('\
		To start the visualization press the start/stop button on the right.<br>\
		To slow down the visualization press the turtle.<br>');
}



function SlowButton() {
		var slow = L.control();

	slow.onAdd = function (map) {
    	this._div = L.DomUtil.create('div', 'slow_button'); // create a div with a class "info"
    	this.update();
    	return this._div;
	};

	slow.update = function(){
		this._div.id = "playpause";
	};


	slow.addTo(mymap);

	if(play_pause==true) {
		$('.slow_button').prepend('<img id="playbg" width="64px" src="./img/turtle.png"/>');
	} else {
		$('.slow_button').prepend('<img id="playbg" width="64px" src="./img/ferrari.png"/>');
	}
	// add the event handler
	function handlePlayPause() {
		// console.log("playpause");

	  	if(play_pause) {
	  		// console.log("stopping");
            play_pause = false;
            document.getElementById("playbg").src="./img/ferrari.png";
        }
	  	else {
	  		// console.log("playing");
            play_pause = true;
            document.getElementById("playbg").src="./img/turtle.png";

		}
	}

	function handleHighlight(){
		// console.log("mouseover");
		this.style.background = "rgba(167,167,167,0)";
	}
	function handleNoHighlight(){
		// console.log("mouseout");
		this.style.background = "rgba(255,255,255,0)";
	}

	document.getElementById ("playpause").addEventListener ("click", handlePlayPause);
	document.getElementById ("playpause").addEventListener ("mouseover", handleHighlight);
	document.getElementById ("playpause").addEventListener ("mouseout", handleNoHighlight);
}


////////////////////////////////////////////////////////////////

function StopButton() {
		var stop_button = L.control();

	stop_button.onAdd = function (map) {
    	this._div = L.DomUtil.create('div', 'stop_button'); // create a div with a class "stop_button"
    	this.update();
    	return this._div;
	};

	stop_button.update = function(){
		this._div.id = "playstop";
	};


	stop_button.addTo(mymap);

	if(play_stop==true) {
		$('.stop_button').prepend('<img id="stopbg" width="64px" src="./img/pause.png"/>');
	} else {
		$('.stop_button').prepend('<img id="stopbg" width="64px" src="./img/play.png"/>');
	}
	// add the event handler
	function handlePlayStop() {
		// console.log("playstop");

	  	if(play_stop) {
	  		// console.log("stopping");
            play_stop = false;
            clearTimeout(timer_id);
            document.getElementById("stopbg").src="./img/play.png";
        }
	  	else {
	  		// console.log("playing");
            play_stop = true;
            document.getElementById("stopbg").src="./img/pause.png";
            runningSim(running_sec); // runningSim is a global var set to the function to be displayed

		}
	}

	function handleHighlight(){
		// console.log("mouseover");
		this.style.background = "rgba(167,167,167,0)";
	}
	function handleNoHighlight(){
		// console.log("mouseout");
		this.style.background = "rgba(255,255,255,0)";
	}

	document.getElementById ("playstop").addEventListener ("click", handlePlayStop);
	document.getElementById ("playstop").addEventListener ("mouseover", handleHighlight);
	document.getElementById ("playstop").addEventListener ("mouseout", handleNoHighlight);
}

//////////////////////////////////////////////////
function ChooseButton() {
		var choose_button = L.control({ position: 'topleft' });

	choose_button.onAdd = function (map) {
    	this._div = L.DomUtil.create('div', 'choose_button'); // create a div with a class "choose_button"
    	this.update();
    	return this._div;
	};

	choose_button.update = function(){
		this._div.id = "choose";
	};


	choose_button.addTo(mymap);

	if(choose_circle==true) {
		$('.choose_button').prepend('<img id="choosebg" width="64px" src="./img/circle.png"/>');
		runningSim = ActiveDoctors;
	} else {
		$('.choose_button').prepend('<img id="choosebg" width="64px" src="./img/graph.png"/>');
		runningSim = PatientPath;
	}
	// add the event handler
	function handleChoose() {
		// console.log("playstop");

	  	if(choose_circle) {
            choose_circle = false; // switch to the graph representation
            clearTimeout(timer_id);
            document.getElementById("choosebg").src="./img/graph.png";
            for(var i in circle_list){
            	circle_list[i].setRadius(200);
            }
            runningSim = PatientPath;
            runningSim(running_day); // runningSim is a global var set to the function to be displayed
        }
	  	else {
            choose_circle = true;
            clearTimeout(timer_id);
            document.getElementById("choosebg").src="./img/circle.png";
            for(var i in link_list){
            	mymap.removeLayer(link_list[i]);
            }
           	runningSim = ActiveDoctors;
            runningSim(running_day); // runningSim is a global var set to the function to be displayed

		}
	}

	function handleHighlight(){
		// console.log("mouseover");
		this.style.background = "rgba(167,167,167,0)";
	}
	function handleNoHighlight(){
		// console.log("mouseout");
		this.style.background = "rgba(255,255,255,0)";
	}

	document.getElementById ("choose").addEventListener ("click", handleChoose);
	document.getElementById ("choose").addEventListener ("mouseover", handleHighlight);
	document.getElementById ("choose").addEventListener ("mouseout", handleNoHighlight);
}
