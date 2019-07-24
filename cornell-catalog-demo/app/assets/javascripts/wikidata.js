var processWikidata = {
  onLoad: function() {
      this.bindEventHandlers();
      var workId = $('*[data-wikiload]').attr('data-wikiload');
      if ( workId.length ) {
          processWikidata.getWikiLocalName(workId);
      }
  },

  bindEventHandlers: function() {
    $('*[data-wikiload]').click(function() {
      var e=$(this);
      var workId = e.data('wikiload');
      //processWikidata.getWikiLocalName(workId);
    });
  },
  
  getWikiLocalName: function(workId) {
    var wikidataEndpoint = "https://query.wikidata.org/sparql?";
    var sparqlQuery = "SELECT ?entity WHERE {?entity wdt:P5331 \"" + workId + "\"}";
    $.ajax({
      url : wikidataEndpoint,
      headers : {
        Accept : 'application/sparql-results+json'
      },
      data : {
        query : sparqlQuery
      },
      success : function(data) {
        if ( data['results']['bindings'].length ) {
            processWikidata.getWikiDerivatives(data['results']['bindings'][0]['entity']['value']);
            processWikidata.getWikiEditions(data['results']['bindings'][0]['entity']['value']);
        } 
        else {
          console.log("woe is me");
        }
      }
    });
  },

  getWikiEditions: function(wikiURI) {
      console.log(wikiURI);
    //var wikidataURI = "http://www.wikidata.org/entity/" + localName;
	var wikidataEndpoint = "https://query.wikidata.org/sparql?";
	var sparqlQuery = "SELECT ?notable_work ?notable_workLabel ?pub_date " 
	                   + "WHERE {?notable_work wdt:P629 <" + wikiURI + "> .  "
	                   + "SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". }"
	                   + " ?notable_work wdt:P577 ?pub_date .}";
    console.log(sparqlQuery);
	$.ajax({
		url : wikidataEndpoint,
		headers : {
			Accept : 'application/sparql-results+json'
		},
		data : {
			query : sparqlQuery
		},
		success : function(data) {
    
			//console.log("Editions of works ");
			//console.log(data);
			if (data && "results" in data
					&& "bindings" in data["results"]) {
				var bindings = data["results"]["bindings"];
				var bLength = bindings.length;
				var b;
				if (bindings.length) {
					var notableWorksOpeningHtml = "<div id='wiki-editions' class='availability panel panel-default'>"
					                                + "<div class='panel-heading'><h3 class='panel-title'>Notable Editions (Wikidata)</h3></div>"
					                                + "<div class='panel-body'>";
					var notableWorksClosingHtml = "</div></div></div>";
					var notableHtmlArray = [];
					var notableWorkURI = "";
					var notableWorkLabel = "";
					var notableWorkPubDate = ""
					for(b = 0; b < bLength; b++) {
						var binding = bindings[b];
						if ("notable_work" in binding
								&& "value" in binding["notable_work"] 
								&& "notable_workLabel" in binding 
								&& "value" in binding["notable_workLabel"]) {
							notableWorkURI = binding["notable_work"]["value"];
							notableWorkLabel = binding["notable_workLabel"]["value"];
    						if ("pub_date" in binding && "value" in binding["pub_date"] ) {
                                notableWorkPubDate = " (" + binding["pub_date"]["value"].substring(0, 4) + ")";
                            }
    						//console.log("uri and label for edition work " + notableWorkURI + ": " + notableWorkLabel + notableWorkPubDate);
    						notableHtmlArray.push("<div class='other-form'><span class='other-form-title'><a href='" + notableWorkURI + "'>" + notableWorkLabel + notableWorkPubDate + "</a></span>");
						}
					}
					notableWorksHtml = notableWorksOpeningHtml + notableHtmlArray.join("</div>") + notableWorksClosingHtml;
					console.log(notableWorksHtml);
					$("#availability-panel").after(notableWorksHtml);
				}
			}
		}
    
	});	
  },
  
  getWikiDerivatives: function(wikiURI) {
  	var wikidataEndpoint = "https://query.wikidata.org/sparql?";
  	var sparqlQuery = "Select ?derivative ?title ?instanceTypeLabel (group_concat(distinct ?pub_date; separator=',') as ?date) "
  	                  + " WHERE {<" + wikiURI + "> wdt:P4969 ?derivative. ?derivative wdt:P1476 ?title.  "
  	                  + "OPTIONAL {?derivative wdt:P31 ?instanceType .} OPTIONAL { ?derivative wdt:P577 ?pub_date . } "
  	                  + "SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". }}"
  	                  + "GROUP BY ?derivative ?title ?instanceTypeLabel";
    console.log(sparqlQuery);
  	$.ajax({
  		url : wikidataEndpoint,
  		headers : {
  			Accept : 'application/sparql-results+json'
  		},
  		data : {
  			query : sparqlQuery
  		},
  		success : function(data) {
    
  			//console.log("Derivative works ");
  			//console.log(data);
  			if (data && "results" in data
  					&& "bindings" in data["results"]) {
  				var bindings = data["results"]["bindings"];
  				var bLength = bindings.length;
  				var b;
  				if (bindings.length) {
					var derivativesOpeningHtml = "<div id='derivatives' class='availability panel panel-default'>"
					                                + "<div class='panel-heading'><h3 class='panel-title'>Derivative Works (Wikidata)</h3></div>"
					                                + "<div class='panel-body'>";
					var derivativesClosingHtml = "</div></div></div>";
					var derivativesHtmlArray = [];
					var derivativesURI = "";
					var derivativesLabel = "";
					var derivativesPubDate = ""
					var instanceTypeLabel = ""
  					for(b = 0; b < bLength; b++) {
  						var binding = bindings[b];
  						if ("derivative" in binding
  								&& "value" in binding["derivative"] 
  								&& "title" in binding 
  								&& "value" in binding["title"]
  						    	) {
  							derivativesURI = binding["derivative"]["value"];
  							derivativesLabel = binding["title"]["value"];
  							if ("instanceTypeLabel" in binding
  							        && "value" in binding["instanceTypeLabel"]) {
  								instanceTypeLabel = binding["instanceTypeLabel"]["value"];
  							}
    						if ("date" in binding && "value" in binding["date"] ) {
                                derivativesPubDate = binding["date"]["value"].substring(0, 4);
                            }
  						//	console.log("uri and label for derivative work " + derivativesURI + ": " + derivativesLabel);
  							derivativesHtmlArray.push("<div class='other-form'><span class='other-form-title'><a href='" + derivativesURI + "'>" + derivativesLabel + " (" + derivativesPubDate + " " + instanceTypeLabel  + ") </a></span>");
  						}
  					}
					derivativesHtml = derivativesOpeningHtml + derivativesHtmlArray.join("</div>") + derivativesClosingHtml;
					console.log(derivativesHtml);
					$("#availability-panel").after(derivativesHtml);
  				}
  			}
  		}
  	});	
  },
  
  getWikiEntity: function(uri) {
    var localName = uri.split("/").pop();
    $.ajax({
      url : "https://www.wikidata.org/wiki/Special:EntityData/" + localName + ".json",
      dataType : "json",
      complete: function(xhr, status) {
        var response = xhr.responseJSON['entities'];
        console.log("Wikidata = " + response.toSource());
      } 
    });
  }
};  
Blacklight.onLoad(function() {
  if ( $('body').prop('className').indexOf("catalog-show") >= 0 ) {
    processWikidata.onLoad();
  }
});  
