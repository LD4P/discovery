// Add autocomplete for the main site search box — ony for Best Bets results
(function ($) {
  $(document).ready(function() {
	$('input#q').each(function() {
	  $(this).autocomplete({
		minLength: 3,
		source: function(request, response) {
	   		 $.ajax({
//	       		 url: 'http://lookup.dbpedia.org/api/search/KeywordSearch?MaxHits=10&QueryString=' + request.term, 
				 url: 'https://www.wikidata.org/w/api.php?action=wbsearchentities&type=item&format=json&language=en&limit=10&search=' + request.term, 
				 type: 'GET',
	       		 dataType: 'jsonp',
	//			 data: {
	//			   q: request.term + "&format=" + format + "&label=" + label,
	//			},
	       		 complete: function(xhr, status) {
					var json = xhr.responseJSON['search'];
					var results = [];
					$.each(json, function() {
						console.log(this.label);
						var label = this.label;
						var desc = this.description;
						results.push(label + " (" + desc + ")");
					});
				   
				   console.log(results);
	           	   response(results);
	       		} 
	   		 });
		},
	  });
  })

/*    if ($('#q').length) {
	  console.log($('#q').val());
      $('#q').autocomplete({
        source: "https://bestbets.library.cornell.edu/match/" + $('#q').val(),
        minLength: 2,
        select: function(event, ui) {
          var url = ui.item.url;
          if (url != '#') {
            location.href = url;
          }
        }
      })
      // This next section is just to add the little external link icon (the <i> class) 
      // after the label in the results list!
      // It can be completely removed if all you need is basic autocomplete
      .data('ui-autocomplete')._renderItem = function(ul, item) {
		  console.log("here => " + $('#q').val());
        return $('<li>')
          .data('item.ui-autocomplete', item)
          .append('<a>' + item.name + '&nbsp;&nbsp;<i class="fa fa-external-link"></i>')
          .append()
          .appendTo(ul);
      }
    }
*/
  });
})(jQuery);

// When the IE9 warning message is dismissed, send an AJAX call to the server
// to remember that fact in the user session so that he/she doesn't keep seeing
// the same message
function hideIE9Warning() {
    $.post('/backend/dismiss_ie9_warning');
}
