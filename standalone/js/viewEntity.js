	class ViewEntity {
	
	  constructor(fusekiURL) {
	  	this.fusekiURL = fusekiURL;
	  	//Saving triples in field
	  	this.triples = [];
	  }
	  init() {
	  	this.initURI();
	  	this.updateHeading();
	  	this.getEntityInfo();
	  }
	  
	  initURI() {
	  	this.uri = this.getUrlParameter("uri");
	  }
	  
	  updateHeading() {
	  	$("#pageheading").append(this.uri);
	  }
	  
	  //Get URL parameter
	 getUrlParameter(sParam) {
	    var sPageURL = window.location.search.substring(1),
	        sURLVariables = sPageURL.split('&'),
	        sParameterName,
	        i;
	
	    for (i = 0; i < sURLVariables.length; i++) {
	        sParameterName = sURLVariables[i].split('=');
	
	        if (sParameterName[0] === sParam) {
	            return sParameterName[1] === undefined ? true : decodeURIComponent(sParameterName[1]);
	        }
	    }
	    return false;
	}
	
	getEntityInfo() {
		//var sajax = this.executeQuery(this.getSubjectQuery(this.uri), this.displaySubjectInfo.bind(this));
		//var oajax = this.executeQuery(this.getObjectQuery(this.uri), this.displayObjectInfo.bind(this));
		var sajax = this.getPromiseQuery(this.getSubjectQuery(this.uri));
		var oajax = this.getPromiseQuery(this.getObjectQuery(this.uri));
		$.when(sajax, oajax).done(function(sres, ores) {
			var sdata = sres[0];
			var odata = ores[0];
			this[0].displaySubjectInfo(sdata);
			this[1].displayObjectInfo(odata);
			this[0].addToGraph(this[0].triples);
		});

	}
	  //Execute query against Fuseki
	  //callbackData is an object you can send with values in case the specific callback function needs to employ additional info
	  executeQuery(query, callback, callbackData) {
	  	var url = this.fusekiURL;
	  	return $.ajax({
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
	  
	  getPromiseQuery(query) {
	  	var url = this.fusekiURL;
	  	return $.ajax({
			url:url,
			context:this,
			data: {
				query: query
			}
		});
	  }
	  //Queries
	   //Queries
	  
	  getPrefixes() {
	  	return "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> " + 
	  	"PREFIX bf: <http://id.loc.gov/ontologies/bibframe/> ";
	  }
	  //Two layers? Start with just direct predicates
	  getSubjectQuery(uri) {
	  	return this.getPrefixes() + "SELECT ?p ?o  WHERE {<"+ uri + "> ?p ?o}";
	  }
	  
	   getObjectQuery(uri) {
	  	return this.getPrefixes() + "SELECT ?s ?p  WHERE {?s ?p <" + uri + ">}";
	  }
	  
	
	  
	  //Display methods
	  //Classes
	  displaySubjectInfo(data) {
	    var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			if (val && "p" in val && "value" in val["p"] 
	  			&& "o" in val && "value" in val["o"]) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var p = val["p"]["value"];
	  				var o = val["o"]["value"];
	  				$("#subject").append("<div class='row'><div class='col'>" + p + "</div><div class='col'>" + o + "</div></div>" );
	  			}
	  		});
	  		//Use these bindings to generate the triples for the graph
	  		//this.updateVisualization(bindings, "subject");
	  		this.triples = this.triples.concat(this.generateTriplesData(bindings, "subject"));

	  	}
	  }
	  
	  displayObjectInfo(data) {
	    var eThis = this;
	   	console.log("displayOInfo");
	    console.log(data);
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			if (val && "p" in val && "value" in val["p"] 
	  			&& "s" in val && "value" in val["s"]) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var p = val["p"]["value"];
	  				var s = val["s"]["value"];
	  				$("#object").append("<div class='row'><div class='col'>" + s + "</div><div class='col'>" + p + "</div></div>" );
	  			}
	  		});
	  		this.triples = this.triples.concat(this.generateTriplesData(bindings, "object"));
	  		//this.updateVisualization(bindings, "object");
	  	}

	  }
	  
	  //Generate data as triples, convert to JSON string, and make graph
	  generateTriplesData(bindings, dataType) {
	  	//if as subject
	  	var eThis = this;
	  	var triples = [];
	  	if(dataType == "subject") {
	  		triples = $.map(bindings, function(val, i) { 
	  			if (val && "p" in val && "value" in val["p"] 
	  			&& "o" in val && "value" in val["o"]) {
	  				var p = val["p"]["value"];
	  				var o = val["o"]["value"];
	  				return {"subject": eThis.uri, "predicate": p, "object": o}
	  			}
	  		});

	  	} else if(dataType == "object") {
	  		triples = $.map(bindings, function(val, i) { 
	  			if (val && "p" in val && "value" in val["p"] 
	  			&& "s" in val && "value" in val["s"]) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var p = val["p"]["value"];
	  				var s = val["s"]["value"];
	  				return {"subject": s, "predicate": p, "object": eThis.uri}
	  			}
	  		});

	  	}
	  	return triples;
	  	//if as object
	  }
	  
	  //Update graph
	  //Relies on methods specified in tripleGraph
	  addToGraph(triples) {
	  	console.log("add to graph");
	  	console.log(triples);
	  	var graph = triplesToGraph(triples);
		update(graph);
	  }
	  
}

$( document ).ready(function() {
    var fusekiURL = configProps["fusekiURL"];
	var viewObj = new ViewEntity(fusekiURL);
	viewObj.init();
});