	class View {
	
	  constructor(fusekiURL) {
	  	this.fusekiURL = fusekiURL;
	  }
	  init() {
	  	//alert("VIEW!");
	  	this.populateSummary();
	  }
	  
	  populateSummary() {
	  	//Populate information about total classes and predicates
	  	var classesQuery = this.getClassesQuery();
	  	this.executeQuery(classesQuery, this.displayClasses.bind(this));
	  	this.executeQuery(this.getPredicatesQuery(), this.displayPredicates.bind(this));
	  	
	  }
	  
	  
	  //Execute query against Fuseki
	  //callbackData is an object you can send with values in case the specific callback function needs to employ additional info
	  executeQuery(query, callback, callbackData) {
	  	console.log("Executing query" + query);
	  	var url = this.fusekiURL;
	  	$.ajax({
			url:url,
			context:this,
			data: {
				query: query
			}
		}).done(function(data) {
			if(callbackData) {
				callback(data, callbackData);
			} else {
				callback(data);
			}
		});
		
	  }
	  
	  //Queries
	  
	  getPrefixes() {
	  	return "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " + 
	  	"PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> ";
	  }
	  getClassesQuery() {
	  	return this.getPrefixes() + "SELECT DISTINCT ?type WHERE {?s rdf:type ?type}";
	  }
	  
	  getClassCountQuery(classURI) {
	  	return this.getPrefixes() + "SELECT (COUNT(DISTINCT ?s) AS ?ct) WHERE {?s rdf:type <" + classURI + ">}";
	  }
	  
	  getPredicatesQuery() {
	  	return this.getPrefixes() + "SELECT DISTINCT ?predicate WHERE {?s ?predicate ?o}";
	  }
	  
	  getPredicatesCountQuery() {
	  	return this.getPrefixes() + "SELECT (COUNT (DISTINCT ?predicate) AS ?ct) WHERE {?s ?predicate ?o}";
	  }
	  
	  //Display methods
	  //Classes
	  displayClasses(data) {
	    var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			if (val && "type" in val && "value" in val["type"]) {
	  				return eThis.displayIndividualClass(val["type"]["value"]);
	  			}
	  		});
	  		$("#classes").append(displayHTML.join(""));
	  	}
	  	//Kick off count ajax queries
	  	this.getClassCounts(bindings);

	  }
	  
	  displayIndividualClass(classURI) {
	  	var classLink = "viewStatements.html?type=subject&uri=" + classURI;
	  	return "<div class='row' uri='" + classURI + "'><div class='col-8'>" + classURI + "</div><div class='col-2' role='count'></div><div class='col-2' role='examples'><a href='" + classLink + "'>Examples</a></div></div>";
	  }
	  
	  getClassCounts(bindings) {
	  	var eThis = this;
  		var uris = $.map(bindings, function(val, i) { 
  			if (val && "type" in val && "value" in val["type"]) {
  				return val["type"]["value"];
  			}
  		});
  		$.each(uris, function(i, v) {
  			eThis.executeQuery(eThis.getClassCountQuery(v),eThis.displayClassCounts.bind(eThis), {"uri":v});
  		});
	  }
	  
	  displayClassCounts(data, callbackData) {
	  	var eThis = this;
	  	var uri = callbackData["uri"];
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			if (val && "ct" in val && "value" in val["ct"]) {
	  				var count = val["ct"]["value"];
	  				$("div[uri='" + uri + "'] div[role='count']").html(count);
	  			}
	  		});
	  	}
	  }
	  
	  
	  //Predicates
	  displayPredicates(data) {
	    var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			if (val && "predicate" in val && "value" in val["predicate"]) {
	  				return eThis.displayIndividualPredicate(val["predicate"]["value"]);
	  			}
	  		});
	  		$("#predicates").append(displayHTML.join(""));
	  	}

	  }
	  
	  displayIndividualPredicate(predicateURI) {
	  	var predicateLink = "viewStatements.html?type=predicate&uri=" + classURI;
	  	return "<div class='row' uri='" + predicateURI + "'><div class='col-8'>" + predicateURI + "</div><div class='col-2' role='count'></div><div class='col-2' role='examples'><a href='" + predicateLink + "'>Examples</a></div></div>";
	  }
	  
	  
	  
	  
}

$( document ).ready(function() {
    var fusekiURL = configProps["fusekiURL"];
	var viewObj = new View(fusekiURL);
	viewObj.init();
});