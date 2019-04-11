$(document).ready(function() {
$('*[data-auth]').click(function() {
    var e=$(this);
     e.off('click');
    var auth = e.attr("data-auth");
    auth = auth.replace(/,\s*$/, "");
    console.log(auth);
        var lookupURL = "http://id.loc.gov/authorities/names/suggest/?q=" + auth + "&rdftype=PersonalName&count=1";
        //Copied from original bfe example
	 $.ajax({
            url: lookupURL,
            dataType: 'jsonp',
            success: function (data) {
              urisArray = parseLOCSuggestions(data);
	      if(urisArray && urisArray.length) {
		var locURI = urisArray[0]; //Pick first one
                e.popover({content: 'URI is ' + locURI, html:true, trigger:'focus'}).popover('show');
              }
            }
	});
      
   
});

//function to process results from LOC lookup

function parseLOCSuggestions(suggestions) {
var urisArray = [];
if ( suggestions && suggestions[1] !== undefined ) {
            for (var s=0; s < suggestions[1].length; s++) {
                //var l = suggestions[1][s];
                var u = suggestions[3][s];
                urisArray.push(u);
            }
}
return urisArray;


}



});
