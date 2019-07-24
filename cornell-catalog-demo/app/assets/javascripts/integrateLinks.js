$(document).ready(function() {
	//getDerivativeWorks();
	//getEditions();
	$('*[data-auth]').click(
			function() {
				var e = $(this);
				e.off('click');
				var auth = e.attr("data-auth");
				auth = auth.replace(/,\s*$/, "");
				//Also periods
				auth = auth.replace(/.\s*$/, "");
				console.log(auth);
				var lookupURL = "http://id.loc.gov/authorities/names/suggest/?q="
					+ auth
					+ "&rdftype=PersonalName&count=1";
				// Copied from original bfe example
				$
				.ajax({
					url : lookupURL,
					dataType : 'jsonp',
					success : function(data) {
						urisArray = parseLOCSuggestions(data);
						if (urisArray
								&& urisArray.length) {
							var locURI = urisArray[0]; // Pick
							// first
							// one
							console.log("LOC URI is "+ locURI);
							queryWikidata(locURI, e);
						}
					}
				});

			});

	// function to process results from LOC lookup

	function parseLOCSuggestions(suggestions) {
		var urisArray = [];
		if (suggestions && suggestions[1] !== undefined) {
			for (var s = 0; s < suggestions[1].length; s++) {
				// var l = suggestions[1][s];
				var u = suggestions[3][s];
				urisArray.push(u);
			}
		}
		return urisArray;

	}

	// Query wikidata
	function queryWikidata(LOCURI, e) {
		// Given loc uri, can you get matching wikidata entities
		var wikidataEndpoint = "https://query.wikidata.org/sparql?";
		var localname = getLocalName(LOCURI);
		var sparqlQuery = "SELECT ?entity WHERE {?entity wdt:P244 \""
			+ localname + "\"}";
		$.ajax({
			url : wikidataEndpoint,
			headers : {
				Accept : 'application/sparql-results+json'
			},
			data : {
				query : sparqlQuery
			},
			success : function(data) {
				console.log("wikidata request");
				console.log(data);
				// Data -> results -> bindings [0] ->
				// entity -> value
				var wikidataURI = parseWikidataSparqlResults(data);
				// Do a popover here with the wikidata uri and the loc uri
				//if no wikidata uri then will just show null
				var contentHtml = "<div id='popoverContent'>";
				contentHtml += "<div>Source: Wikidata</div><div id='entityImage'></div>";
				//<div>LOC: " + LOCURI + "</div>";
				//contentHtml += "<div>Wikidata: " + wikidataURI + "</div>";
				contentHtml += "</div>";
				//Get notable results
				if(wikidataURI != null) {
					getImage(wikidataURI);
					getNotableWorks(wikidataURI);
					getInfluencedBy(wikidataURI);
				}
				e.popover(
						{
							content : contentHtml,
								html : true,
								trigger : 'focus'
						}).popover('show');

			}

		});

	}

	// function to parse sparql query results from wikidata
	function parseWikidataSparqlResults(data) {

		if (data && "results" in data
				&& "bindings" in data["results"]) {
			var bindings = data["results"]["bindings"];
			if (bindings.length) {
				var binding = bindings[0];
				if ("entity" in binding
						&& "value" in binding["entity"]) {
					var uriValue = binding["entity"]["value"];
					console.log("wikidata uri is " + uriValue);
					return uriValue;
				}
			}
		}
		return null;

	}

	//function to get localname from LOC URI
	function getLocalName(uri) {
		//Get string right after last slash if it's present
		//TODO: deal with hashes later
		return uri.split("/").pop();
	}
	
	//Wikidata entity
	function retrieveWikidataEntity(wikidataURI) {
		
	}
	
	//Wikidata notable works
	function getNotableWorks(wikidataURI){
		var wikidataEndpoint = "https://query.wikidata.org/sparql?";
		var sparqlQuery = "SELECT ?notable_work ?title WHERE {<" + wikidataURI + "> wdt:P800 ?notable_work. ?notable_work wdt:P1476 ?title. }";
	
		$.ajax({
			url : wikidataEndpoint,
			headers : {
				Accept : 'application/sparql-results+json'
			},
			data : {
				query : sparqlQuery
			},
			success : function(data) {
				
				console.log("Notable works ");
				console.log(data);
				if (data && "results" in data
						&& "bindings" in data["results"]) {
					var bindings = data["results"]["bindings"];
					var bLength = bindings.length;
					var b;
					if (bindings.length) {
						var notableWorksHtml = "<div>Notable Works: ";
						var notableHtmlArray = [];
						for(b = 0; b < bLength; b++) {
							var binding = bindings[b];
							if ("notable_work" in binding
									&& "value" in binding["notable_work"] 
									&& "title" in binding 
									&& "value" in binding["title"]) {
								var notableWorkURI = binding["notable_work"]["value"];
								var notableWorkLabel = binding["title"]["value"];
								console.log("uri and label for notable work " + notableWorkURI + ":" + notableWorkLabel);
								notableHtmlArray.push("<a href='" + notableWorkURI + "'>" + notableWorkLabel + "</a>");
							}
						}
						notableWorksHtml += notableHtmlArray.join(", ") + "</div>";
						$("#popoverContent").append(notableWorksHtml);
					}
				}
			}

		});
	}
	
	//Wikidata influenced by
	function getInfluencedBy(wikidataURI){
		var wikidataEndpoint = "https://query.wikidata.org/sparql?";
		var sparqlQuery = "SELECT ?influencedBy ?influencedByLabel WHERE {?influencedBy wdt:P737 <" + wikidataURI + "> . SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". } }";
	
		$.ajax({
			url : wikidataEndpoint,
			headers : {
				Accept : 'application/sparql-results+json'
			},
			data : {
				query : sparqlQuery
			},
			success : function(data) {
				
				console.log("Influenced By ");
				console.log(data);
				if (data && "results" in data
						&& "bindings" in data["results"]) {
					var bindings = data["results"]["bindings"];
					var bLength = bindings.length;
					var b;
					if (bindings.length) {
						var notableWorksHtml = "<div>Influenced: ";
						var notableHtmlArray = [];
						for(b = 0; b < bLength; b++) {
							var binding = bindings[b];
							if ("influencedBy" in binding
									&& "value" in binding["influencedBy"] 
									&& "influencedByLabel" in binding 
									&& "value" in binding["influencedByLabel"]) {
								var iURI = binding["influencedBy"]["value"];
								var iLabel = binding["influencedByLabel"]["value"];
								console.log("uri and label for influenced  " + iURI + ":" + iLabel);
								notableHtmlArray.push("<a href='iURI'>" + iLabel + "</a>");
							}
						}
						notableWorksHtml += notableHtmlArray.join(", ") + "</div>";
						$("#popoverContent").append(notableWorksHtml);
					}
				}
			}

		});
	}
	//Get Image
	function getImage(wikidataURI){
		var wikidataEndpoint = "https://query.wikidata.org/sparql?";
		var sparqlQuery = "SELECT ?image WHERE {<" + wikidataURI + "> wdt:P18 ?image . }";
	
		$.ajax({
			url : wikidataEndpoint,
			headers : {
				Accept : 'application/sparql-results+json'
			},
			data : {
				query : sparqlQuery
			},
			success : function(data) {
				
				console.log("Image ");
				console.log(data);
				if (data && "results" in data
						&& "bindings" in data["results"]) {
					var bindings = data["results"]["bindings"];
					var bLength = bindings.length;
					var b;
					if (bindings.length) {
						var notableWorksHtml = "<img src=' ";
						var binding = bindings[0];
						if ("image" in binding
								&& "value" in binding["image"] ) {
							var image = binding["image"]["value"];
							$("#entityImage").append("<img style='max-width:100px;max-height:100px' src='" + image + "'>");

						}
					}
					
				}
			}

		});
	}
	
	//Hard coded derived works
	function getDerivativeWorks() {
		//Hardcoded, to be retrieved somehow later
		var wikidataURI = "http://www.wikidata.org/entity/Q170583";
		var wikidataEndpoint = "https://query.wikidata.org/sparql?";
		var sparqlQuery = "SELECT ?notable_work ?title ?instanceTypeLabel WHERE {<" + wikidataURI + "> wdt:P4969 ?notable_work. ?notable_work wdt:P1476 ?title.  OPTIONAL {?notable_work wdt:P31 ?instanceType .} SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". }}";
	
		$.ajax({
			url : wikidataEndpoint,
			headers : {
				Accept : 'application/sparql-results+json'
			},
			data : {
				query : sparqlQuery
			},
			success : function(data) {
				
				console.log("Derivative works ");
				console.log(data);
				if (data && "results" in data
						&& "bindings" in data["results"]) {
					var bindings = data["results"]["bindings"];
					var bLength = bindings.length;
					var b;
					if (bindings.length) {
						var notableWorksHtml = "<li class='list-group-item citation'>Derivative (Wikidata):  <br/>";
						var notableHtmlArray = [];
						for(b = 0; b < bLength; b++) {
							var binding = bindings[b];
							if ("notable_work" in binding
									&& "value" in binding["notable_work"] 
									&& "title" in binding 
									&& "value" in binding["title"]
							    	) {
								var notableWorkURI = binding["notable_work"]["value"];
								var notableWorkLabel = binding["title"]["value"];
								var instanceTypeLabel = "";
								if("instanceTypeLabel" in binding
								        && "value" in binding["instanceTypeLabel"])
									instanceTypeLabel = "(" + binding["instanceTypeLabel"]["value"] + ")";
								console.log("uri and label for derivative work " + notableWorkURI + ":" + notableWorkLabel);
								notableHtmlArray.push("<a href='" + notableWorkURI + "'>" + notableWorkLabel + " " + instanceTypeLabel + " </a>");
							}
						}
						notableWorksHtml += notableHtmlArray.join("<br/>") + "</li>";
						$("#related_works").append(notableWorksHtml);
					}
				}
			}

		});	
	}
	
	function getEditions() {
		//Hard coded URI, to be retrieved somehow later
		var wikidataURI = "http://www.wikidata.org/entity/Q170583";
		var wikidataEndpoint = "https://query.wikidata.org/sparql?";
		var sparqlQuery = "SELECT ?notable_work ?notable_workLabel WHERE {?notable_work wdt:P629 <" + wikidataURI + "> .  SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". } }";
	
		$.ajax({
			url : wikidataEndpoint,
			headers : {
				Accept : 'application/sparql-results+json'
			},
			data : {
				query : sparqlQuery
			},
			success : function(data) {
				
				console.log("Editions of works ");
				console.log(data);
				if (data && "results" in data
						&& "bindings" in data["results"]) {
					var bindings = data["results"]["bindings"];
					var bLength = bindings.length;
					var b;
					if (bindings.length) {
						var notableWorksHtml = "<li class='list-group-item citation'>Editions or Translations (Wikidata):  <br/>";
						var notableHtmlArray = [];
						for(b = 0; b < bLength; b++) {
							var binding = bindings[b];
							if ("notable_work" in binding
									&& "value" in binding["notable_work"] 
									&& "notable_workLabel" in binding 
									&& "value" in binding["notable_workLabel"]) {
								var notableWorkURI = binding["notable_work"]["value"];
								var notableWorkLabel = binding["notable_workLabel"]["value"];
								console.log("uri and label for edition work " + notableWorkURI + ":" + notableWorkLabel);
								notableHtmlArray.push("<a href='" + notableWorkURI + "'>" + notableWorkLabel + "</a>");
							}
						}
						notableWorksHtml += notableHtmlArray.join("<br/> ") + "</li>";
						$("#related_works").append(notableWorksHtml);
					}
				}
			}

		});	
	}
	
	
	//LOC: function to get JSON for LOC URI
	//VIAF: function to call VIAF and extract same as relationships
	//?Also potentially selected co-author relationships?
	

});
