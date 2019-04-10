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
              console.log("what is the data");console.log(data);
              return data;
            }
	});
        e.popover({content: 'http://www.google.com', html:true, trigger:'focus'}).popover('show');
   
});
});
