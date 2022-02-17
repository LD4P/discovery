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
	  	this.executeQuery(this.getStatementsQuery(), this.displayStatements.bind(this));

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
	  getStatementsQuery() {
	  	return this.getPrefixes() + "SELECT ?s ?p ?o WHERE {?s ?p ?o} LIMIT 200";
	  }


	  //Display methods
	  //Classes
	  displayStatements(data) {
	    var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) {
	  			return eThis.displayIndividualStatement(val["s"]["value"], val["p"]["value"], val["o"]["value"]);  			
	  		});
	  		//Hide ellipses
	  		$("#loadingStatements").addClass("d-none");
	  		$("#statements").append(displayHTML.join(""));
	  	}

	  }

	  displayIndividualStatement(s, p, o) {
	  	var subjectLink = "viewEntity.html?uri=" + s;
	  	var objectDisplay = (o.startsWith("http://") || o.startsWith("https://"))? "<a href='viewEntity.html?uri=" + o + "'>" + o + "</a>": o;
	  	var predicateLink = "viewStatements.html?type=predicate&uri=" + p;
	  	return "<div class='row'><div class='col'><a href='" + subjectLink + "'>" + s +  "</a></div><div class='col'><a href='" + predicateLink + "'>" + p + "</a></div><div class='col'>" + objectDisplay + "</div></div>";
	  }
}

$( document ).ready(function() {
    var fusekiURL = configProps["fusekiURL"];
	var viewObj = new View(fusekiURL);
	viewObj.init();
});