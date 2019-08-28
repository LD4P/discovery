var buildAlternateSuggestions = {
  onLoad: function() {
    var q = $('input#q').val();
    if (q.length) {
        this.makeAjaxCalls(q);
    }
  },

  // function checks each suggested search to display only those with > 0 catalog results
  checkSuggestions: function(suggestions) {
    var facetList = '&facet.query=' + suggestions.join('&facet.query=')
    var solrQuery = "http://da-prod-solr8.library.cornell.edu/solr/ld4p2-blacklight/select?indent=on&wt=json&rows=0&q=*.*&facet=true" + facetList
    $.ajax({ // would be nice to pull url from env var rather than directly include it in code
      url: solrQuery,
      type: 'GET',
      dataType: 'jsonp',
      jsonp: 'json.wrf', // avoid CORS and CORB errors
      complete: function(response) {
        var countsList = response["responseJSON"]["facet_counts"]["facet_queries"];
        buildAlternateSuggestions.displaySuggestions(Object.keys(countsList));
      }
    });    
  },

  makeAjaxCalls: function(q) {
    console.log("makeAjaxCalls");
    var results = [];
    var dbp_done = false;
    var wiki_done = false;
    $.ajax({
        url: 'https://www.wikidata.org/w/api.php?action=wbsearchentities&type=item&format=json&language=en&limit=8&search=' + q.replace(/ /g, "+"), 
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
            console.log("Wikidata = " + count);
            wiki_done = true;
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
            console.log("DBpedia = " + count);
            dbp_done = true;
        } 
    });    
    $.ajax({
        url: 'https://lookup.ld4l.org/authorities/search/linked_data/locsubjects_ld4l_cache?&maxRecords=8&q=' + q.replace(/ /g, "+"), 
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
            console.log("LoC = " + count);
            // once search suggestions come in from all sources, check them against the catalog
            if ( wiki_done == true && dbp_done == true ) {
                buildAlternateSuggestions.checkSuggestions(results);
            }
            else {
                setTimeout(function() {
                        buildAlternateSuggestions.checkSuggestions(results);
                }, 1000)
            }
        } 
    });
  },
  
  retainLabel: function(q, label, desc) {
      if ( q.toLowerCase() == label.toLowerCase() ) {
          return false;
      }
      else if ( q.toLowerCase() == label.toLowerCase().replace("the ","") ) {
            return false;
      }
      if ( desc.indexOf("article") >= 0 ) {
          return false;
      }
      if ( label.indexOf("Wikipedia:") >= 0 ) {
          return false;
      }
      if ( label.indexOf("disambiguation") >= 0 ) {
          return false;
      }
      return true;
  },


  displaySuggestions: function(suggestions) {
      var opening_html = "<div class='expand-search'><div class='panel panel-default'><div class='panel-heading'><h3 class='panel-title'>Related searches</h3>"
                     + "</div><div class='panel-body'><ul class='fa-ul'>";
      var closing_html = "</ul></div></div></div>";
      var list_html = "";
      if ( suggestions.length ) {
          suggestions = $.unique(suggestions.sort());
          // console.log("results = " + suggestions.toSource());
          $.each(suggestions, function(i, val) {
                list_html += "<li style='padding-left:16px;text-indent:-8px;'><i class='fa fa-search fa-inverse' aria-hidden='true' alt=''></i>"
                             + "<a href='/catalog?only_path=true&q=" + val.replace(/ /g, "+").replace(/--/g, "+")  
                             + "&search_field=all_fields&utf8=%E2%9C%93'>"
                             + val 
                             + "</a></li>";
          });
          $("#expanded-search").append(opening_html + list_html + closing_html);
      }
  }

};  
  
