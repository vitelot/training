function Initmap() {

  	// set up the map
  	mymap = new L.Map('mapid');

    //create the tile layer with correct attribution
    var osmUrl='http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
    //var osmUrl='http://{s}.tiles.wmflabs.org/bw-mapnik/{z}/{x}/{y}.png';
  	//var osmUrl='http://{s}.tile.stamen.com/toner/{z}/{x}/{y}.png';

  	var osmAttrib='VDPS@CSH | Map data © <a href="http://openstreetmap.org">OpenStreetMap</a> contributors';
  	var osm = new L.TileLayer(osmUrl, {minZoom: 8, maxZoom: 99, attribution: osmAttrib});

  	// start the map in Austria
    //mymap.setView(new L.LatLng(47.488, 12.881),7); // whole Austria
    mymap.setView(new L.LatLng(48.0179, 16.2865),10);
  	mymap.addLayer(osm);

    var info = L.control();
    info.onAdd = function (map) {
          this._div = L.DomUtil.create('div', 'info'); // create a div with a class "info"
          //this.update();
          return this._div;
        };
    info.addTo(mymap);

}

function getRandomColor() {
    var letters = '0123456789ABCDEF';
    var color = '#';
    for (var i = 0; i < 6; i++ ) {
        color += letters[Math.floor(Math.random() * 16)];
    }
    return color;
}

function DrawBS() {
  var oReq = new XMLHttpRequest();
  var docs = [];
    oReq.onload = reqListener;
    oReq.open("get", "./data/betriebstellen.json", true); // false: work synchronously
    oReq.send();

    function reqListener(e) {
      docs = JSON.parse(this.responseText);

      for(var i=0; i<docs.length; i++) {
        var doctor = docs[i];
        var circle = L.circle([doctor.lat, doctor.long], {
            color: 'Null',
            fillColor: 'rgb(0,200,0)',
            fillOpacity: 0.8,
            radius: 500
        }).addTo(mymap);

        circle_list[doctor.id] = circle;

        circle.bindPopup(
            "<p class=\"circlepopup\">"+
            "      Id: "+doctor.id.toString()+
            "<br />Km: "+doctor.km.toString()+
            // "<br />FG:"+doctor.fg.toString()+
            // "<br />BZ:"+doctor.land_name.toString()+
            "</p>"
        );
        circle.on('mouseover', function (e) {
              var zoom = mymap.getZoom();
              if(zoom < 12) {
                this.setRadius(2000);
              } else {
                this.setRadius(1000);
              }
              this.setStyle( {
                fillOpacity: 0.5,
                color: 'black'
              })
              this.openPopup();
          });
        circle.on('mouseout', function (e) {
              this.setRadius(500);
              this.setStyle( {
                fillOpacity: 0.8,
                color: 'Null'
              })
              this.closePopup();
        });
      }

    }
}

function getColorFromFG(fg) {
        //var number = (Math.floor(1e7*Math.tan(fg*1.5))%parseInt('FFFFFF',16)).toString(16);
        var number = parseInt(fg);
        //console.log(number);
        var color;
        switch(number) {
          case 1:
          case 7:
          case 8:
          case 47:
          case 48: color = '#FFAA00'; break; // primary doctors
          case 59:
          case 60: color = '#FF00FF'; break; // farmacies
          case 50:
          case 51:
          case 52:
          case 55: color = '#0000FF'; break; // Labs
          default: color = '#00FFFF'; break;
        }

        //var color = '#'+number;
        return color;
}

function dayofWeek(d) {
  var n = parseInt(d);
  switch(n%7) {
    case 0: return "Sat";
    case 1: return "Sun";
    case 2: return "Mon";
    case 3: return "Tue";
    case 4: return "Wed";
    case 5: return "Thu";
    case 6: return "Fri";
  }
}

function delay2color(delay) {
    let bad_delay = 300 // seconds

    if(delay<0) delay=0;

    let r = Math.min(1.0, delay/bad_delay);

    let red = Math.floor(200*r);
    let green = 200-red; //Math.floor(200*(1-r));
    let blue = 0

    return int2rgb([red,green,blue])
}

function rgb2int(color) {
  // var rgbColor = 'rgb(46, 123, 14)';
  // rgbArr = rgbColor.substring(4, rgbColor.length-1).replace(/ /g, '').split(',');
  // console.log(rgbArr);

    astring = color.substring(4, color.length-1).split(',');
    aint = [0,0,0];
    for(i=0; i<3; i++) {
      aint[i] = parseInt(astring[i])
    }
    return aint
}

function int2rgb(a) {
  return 'rgb('+a[0].toString()+','+a[1].toString()+','+a[2].toString()+')';
}


////////////////////////////////////////////////
////////////////////////////////////////////////
////////////////////////////////////////////////
////////////////////////////////////////////////
function runningSim(starting_sec=0) {
  // starting_sec = (typeof start !== 'undefined') ?  start : 0;
  // runningSim = ActiveTrains;

  running_sec = starting_sec;

  if(play_stop==false) return;

  var oReq = new XMLHttpRequest();
  var transits = [];
    oReq.onload = reqListener;
    oReq.open("get", "./data/04.02.19-sec.json", true); // false: work synchronously
    oReq.send();

    function reqListener(e) {
      transits = JSON.parse(this.responseText);

      // var circle_list = {}; moved to globals.js
      // var display_circle = {};
      var maxsec = 0;


      var transit_array = {};
      for(var i in transits) {
        var transit = transits[i];
        var bscode = transit.bscode;
        rsec = parseInt(transit.realtime);
        sec = parseInt(transit.duetime);
        if(!transit_array[rsec]) {
            transit_array[rsec] = [];
        }
        if(maxsec<rsec) maxsec = rsec;
        transit_array[rsec].push([bscode, rsec-sec]);
      }

      transits = [];

      var intertime = 20; // milliseconds of delay between two days
      setTimeout(Play, 50, starting_sec); //Start simulation after delay, from day given

      function Play(d) { // uses a recursive setTimeout
        if(running_sec>=maxsec) return;

        if(play_pause == false) intertime = 500; // abrupt interaction
        if(play_pause == true && intertime == 500) {
          intertime = 20; // abrupt interaction
        }

        running_sec = ++d;

        for(c in circle_list) { // reduce the radius of all circles
          reduceRadius(circle_list[c]);
          reduceColor(circle_list[c]);
        }

        var nrtrains = 0;
        for(var events in transit_array[d]) {
          var bscode = transit_array[d][events][0];
          var delay = transit_array[d][events][1];

          { // increase the radius of doctors active that day
            increaseRadius(circle_list[bscode]); /////
            circle_list[bscode].setStyle({fillColor: delay2color(delay)})
            nrtrains++;
          }
        }
        //return;

        hour=String(Math.floor(d/3600)).padStart(2,'0');
        minute = String(Math.floor(d/60)-hour*60).padStart(2,'0');
        second = String(d%60).padStart(2,'0');

        var x=document.getElementsByClassName("info");  // Find the element
        x[0].innerHTML =
          hour+":"+minute+":"+second+"<br><br><br>"+
          "<span style=\"color: #ff0000; font-size: 60%\" >"+
          "#Transits:"+("0000"+String(nrtrains)).slice(-4)+    // padding zeroes
          "</span>";
        if (d < maxsec) timer_id=setTimeout(Play, intertime, d);
      }


      function reduceRadius(circle) {
        var radius = circle.getRadius();
        if(radius>500) {
          circle.setRadius(radius/1.01);
        }
      }

      function increaseRadius(circle) {
        var radius = circle.getRadius();
        if(radius<1000) {
          circle.setRadius(radius*1.5);
        }
      }
      function reduceColor(circle) {
        let damp = 1.05;
        [r,g,b] = rgb2int(circle.options.fillColor)
        r = Math.floor(r/damp)
        g = 200 - r; //Math.floor( 200 - (200-g)/damp )

        circle.setStyle({fillColor: int2rgb([r,g,b])})
      }
    } // end: reqListener()
}  // end:ActiveTrains()
