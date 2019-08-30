var buildAlternateSuggestions = {
  onLoad: function() {
    var q = $('input#q').val();
    if (q.length) {
      this.gatherSuggestions(q);
        //this.makeAjaxCalls(q);
    }
  },

  // function checks each suggested search to display only those with > 0 catalog results
  checkSuggestions: function(suggestions) {
    // first, the suggestions will be checked all at once with a faceted catalog solr query
    var facetList = '&facet.query=' + suggestions.join('&facet.query=')
    var solrQuery = "http://da-prod-solr8.library.cornell.edu/solr/ld4p2-blacklight/select?indent=on&wt=json&rows=0&q=*.*&facet=true" + facetList
    $.ajax({ // would be nice to pull url from env var rather than directly include it in code
      url: solrQuery,
      type: 'GET',
      dataType: 'jsonp',
      jsonp: 'json.wrf', // avoid CORS and CORB errors
      complete: function(response) {
        // suggestions from query return that have nonzero catalog result counts "survive" the check
        var survivingSuggestions = Object.keys(response["responseJSON"]["facet_counts"]["facet_queries"]);
        // use array subtraction to get zero-count (non-surviving) suggestions
        var suggestionsToDoubleCheck = suggestions.filter(n => !survivingSuggestions.includes(n));
        // double-check these zero-count suggestions with nonfaceted search requests
        var ajaxRequests = buildAlternateSuggestions.ajaxRequestsForDoubleCheck(suggestionsToDoubleCheck);
        var whenRequests = $.when.apply($, ajaxRequests); // run each double-check request
        whenRequests.done(function( x ) {
          $.each(arguments, function(index, responseData){
            // when Ajax is done done, get JSON from responseData, an array of response info per request
            var solrDoublecheckResults = responseData[2].responseJSON
            // if there were more than zero catalog results, the suggestion has passed the double-check test
            if (solrDoublecheckResults.response.numFound > 0) {
              // add the passing search suggestion string into the list to be show to the user
              survivingSuggestions.push(solrDoublecheckResults.responseHeader.params.q)
            }
          });
          // display the suggestions that have nonzero catalog result counts
          buildAlternateSuggestions.displaySuggestions(survivingSuggestions);
        });
      }
    });
  },

  // function creates an (unexecuted) solr catalog Ajax request promise for each unique string in a list of suggested searches
  // these will be used by checkSuggestions() to double-check each suggestion that didn't pass the faceted catalog check
  ajaxRequestsForDoubleCheck: function(suggestions) {
    var requests = []; // function returns an array of other functions, each of which is an Ajax request
    var unique = [...new Set(suggestions)]; // compell suggestion strings to be unique
    $.each(unique, function(i, val) {
      var solrQuery = "http://da-prod-solr8.library.cornell.edu/solr/ld4p2-blacklight/select?wt=json&rows=0&facet=false&q=" + val
      requests.push( // add each Ajax request to the array
        $.ajax({
          url: solrQuery,
          type: 'GET',
          dataType: 'jsonp',
          jsonp: 'json.wrf' // avoid CORS and CORB errors
        })
      );
    });
    return requests;
  },

  gatherSuggestions: function(q) {
    var ajaxRequests = buildAlternateSuggestions.ajaxRequestsForSuggestedSearches(q); // get array of requests
    var whenRequests = $.when.apply($, ajaxRequests); // run each request in the array
    whenRequests.done(function(ld4l, dbpedia, wikidata){
      // process WikiData response
      var wikidataFiltered = wikidata[0].search.filter(function(item) {return buildAlternateSuggestions.retainLabel(q, item.label, item.description)})
      var wikidataMapArray = wikidataFiltered.map(x => x.label);
      console.log("WikiData suggestions: " + wikidataMapArray);
      // process LD4L response
      var ld4lFiltered = ld4l[0].filter(function(item) {return buildAlternateSuggestions.retainLabel(q, item.label, '')})
      var ld4lMapArray = ld4lFiltered.map(x => x.label);
      console.log("LD4L suggestions: " + ld4lMapArray);
      //process DBpedia response
      var dbpediaFiltered = dbpedia[0].results.filter(function(item) {return buildAlternateSuggestions.retainLabel(q, item.label, '')})
      var dbpediaMapArray = dbpediaFiltered.map(x => x.label);
      console.log("DBpedia suggestions: " + dbpediaMapArray);

      // join the arrays coming back from each Ajax request
      joinedArrays = ld4lMapArray.concat(dbpediaMapArray).concat(wikidataMapArray);

      buildAlternateSuggestions.checkSuggestions(joinedArrays);
    }).fail( function(d, textStatus, error) {
      console.error("getJSON failed, status: " + textStatus + ", error: "+error)
    });
  },

  // set up ajax requests and return them
  ajaxRequestsForSuggestedSearches: function(q) {
    var queryStringNoSpace = q.replace(/ /g, "+");
    var ajaxParametersList = [
      {
        url: 'https://lookup.ld4l.org/authorities/search/linked_data/locsubjects_ld4l_cache?&maxRecords=8&q=' + queryStringNoSpace, 
        type: 'GET',
        dataType: 'json'
      },
      {
        url: 'http://lookup.dbpedia.org/api/search/KeywordSearch?MaxHits=8&QueryString=' + queryStringNoSpace, 
        type: 'GET',
        dataType: 'json'
      },
      {
        url: 'https://www.wikidata.org/w/api.php?action=wbsearchentities&type=item&format=json&language=en&limit=8&search=' + queryStringNoSpace,
        type: 'GET',
        dataType: 'jsonp'
      }
    ];
    // Return an array of Ajax promises
    return ajaxParametersList.map(p => $.ajax(p));
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
  
Blacklight.onLoad(function() {
  $('body.catalog-index').each(function() {
    buildAlternateSuggestions.onLoad();
  });
});
