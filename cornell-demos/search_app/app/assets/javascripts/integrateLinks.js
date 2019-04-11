$(document).ready(function() {
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
				var contentHtml = "<div>LOC: " + LOCURI + "</div>";
				contentHtml += "<div>Wikidata: " + wikidataURI + "</div>";
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
	
	//LOC: function to get JSON for LOC URI
	//VIAF: function to call VIAF and extract same as relationships
	

});
