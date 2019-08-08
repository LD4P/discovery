var buildAlternateSuggestions = {
  onLoad: function() {
    var q = $('input#q').val();
    if (q.length) {
        this.makeAjaxCalls(q);
    }
  },

  makeAjaxCalls: function(q) {
    var results = [];
    $.ajax({
        url: 'https://www.wikidata.org/w/api.php?action=wbsearchentities&type=item&format=json&language=en&limit=8&search=' + q.replace(/ /g, "+"), 
        async: false,
        type: 'GET',
        dataType: 'jsonp',
     	complete: function(xhr, status) {
            var json = xhr.responseJSON['search'];
            var count = 0;
            $.each(json, function() {
                var label = this.label;
                var desc = this.description;
                if ( !desc ) {
                    desc = "";
                }
                if ( buildAlternateSuggestions.retainLabel(q, label, desc) ) {
                    results.push(label);
                    count++;                    
                }
  		    });
            console.log("Wikidata - " + Date($.now()) + " : " + count);
        } 
    });
    $.ajax({
	    url: 'http://lookup.dbpedia.org/api/search/KeywordSearch?MaxHits=8&QueryString=' + q.replace(/ /g, "+"), 
        type: 'GET',
        dataType: 'xml',
 		success: function(xml) {
            var count = 0;
 		    $(xml).find('Result').each(function() {
                var label = $(this).children('Label').text();
                if ( buildAlternateSuggestions.retainLabel(q, label, "") ) {
                    results.push(label);
                    count++;                    
                }
            });
            console.log("DBpedia = " + Date($.now()) + " : " + count);
        } 
    });    
    $.ajax({
        url: 'https://lookup.ld4l.org/authorities/search/linked_data/locsubjects_ld4l_cache?&maxRecords=8&q=' + q.replace(/ /g, "+"), 
        async: false,
        type: 'GET',
        dataType: 'json',
     	complete: function(xhr, status) {
            var json = $.parseJSON(xhr.responseText);
            var count = 0;
            $.each(json, function() {
                var label = this.label;
                if ( buildAlternateSuggestions.retainLabel(q, label, "") ) {
                    results.push(label);
                    count++;                    
                }
  		    });
            console.log("LoC = " + Date($.now()) + " : " + count);
        } 
    });
//    setTimeout(function() {
        buildAlternateSuggestions.processResults(results);
//    }, 1500)
  },
  
  retainLabel: function(q, label, desc) {
      if ( q.toLowerCase() == label.toLowerCase() ) {
          return false;
      }
      if ( desc.indexOf("article") >= 0 ) {
          return false;
      }
      return true;
  },

  processResults: function(results) {
      console.log("processResults");
      var opening_html = "<div class='expand-search'><div class='panel panel-default'><div class='panel-heading'><h3 class='panel-title'>Related searches</h3>"
                     + "</div><div class='panel-body'><ul class='fa-ul'>";
      var closing_html = "</ul></div></div></div>";
      var list_html = "";
      if ( results.length ) {
          results = $.unique(results.sort());
          $.each(results, function(i, val) {
                list_html += "<li><i class='fa fa-search fa-inverse' aria-hidden='true' alt=''></i>"
                             + "<a href='/catalog?only_path=true&q=" + val.replace(/ /g, "+") 
                             + "&search_field=all_fields&utf8=%E2%9C%93'>"
                             + val 
                             + "</a></li>";
          });
          $("div.expand-search").append(opening_html + list_html + closing_html);
      }
  }

};
Blacklight.onLoad(function() {
  $('body.catalog-index').each(function() {
    buildAlternateSuggestions.onLoad();
  });
});
