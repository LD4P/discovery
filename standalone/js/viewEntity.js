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
	  	this.bindEventHandlers();
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
	
	//actions: get entity info
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
	
	getExpandedInfo() {
		this.executeQuery(this.getExpandQuery(this.uri), this.displayExpansion.bind(this));
	}
	
	//helper methods
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
	  
	 //check if sparql result has values for a set of variable names
	 hasResultValues(val, varNames) {
	 	var hasValues = true;
	 	var eThis = this;
	 	$.each(varNames, function(i, k) {
	 		if(!eThis.hasResultIndividualValue(val, k)) {
	 			hasValues = false;
	 			return false;
	 		}
	 		
	 	});
	 	return hasValues;
	 }  
	 
	 hasResultIndividualValue(val, name) {
	 	return(name in val && "value" in val[name]); 
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
	  
	  //Level = 0 is itself, 2 means two more layers down, etc.
	  //Query 
	  getExpandQuery(uri) {
	  	return this.getPrefixes() + "SELECT ?o ?p1 ?o1 WHERE {<" + uri + "> ?p ?o . ?o ?p1 ?o1 .}"; 
	  }
	
	  
	  //Display methods
	  //Classes
	  displaySubjectInfo(data) {
	    var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			var htmlLine = "";
	  			if (val && "p" in val && "value" in val["p"] 
	  			&& "o" in val && "value" in val["o"]) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var p = val["p"]["value"];
	  				var o = val["o"]["value"];
	  				//generate link for object URIs
	  				if( !(p == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type") && (o.startsWith("http://") || o.startsWith("https://"))) {
	  				 	o = "<a href='viewEntity.html?uri=" + o + "'>" + o + "</a>"; 
	  				 }
	  				htmlLine = "<div class='row'><div class='col'>" + p + "</div><div class='col'>" + o + "</div></div>";
	  			}
	  			return htmlLine;
	  		});
	  		//Use these bindings to generate the triples for the graph
	  		//this.updateVisualization(bindings, "subject");
	  		$("#subject").append(displayHTML.join(" "));
	  		this.triples = this.triples.concat(this.generateTriplesData(bindings, "subject"));

	  	}
	  }
	  
	  displayObjectInfo(data) {
	    var eThis = this;
	   	
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			var htmlLine = "";
	  			if (val && "p" in val && "value" in val["p"] 
	  			&& "s" in val && "value" in val["s"]) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var p = val["p"]["value"];
	  				var s = val["s"]["value"];
	  				//generate link for object URIs
	  				if( !(p == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type") && (s.startsWith("http://") || s.startsWith("https://"))) {
	  				 	s = "<a href='viewEntity.html?uri=" + s + "'>" + s + "</a>"; 
	  				 }
	  				htmlLine = "<div class='row'><div class='col'>" + s + "</div><div class='col'>" + p + "</div></div>";
	  			}
	  			return htmlLine;
	  		});
	  		$("#object").append(displayHTML.join(" "));
	  		this.triples = this.triples.concat(this.generateTriplesData(bindings, "object"));
	  		//this.updateVisualization(bindings, "object");
	  	}

	  }
	  
	  
	  displayExpansion(data) {
	  	var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//p2 and o2 are optional
	  		var expansionVarNames = ["o", "p1", "o1"];
	  		//var optoinalVarNames = ["p2", "o2"];
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			var htmlLine = "";
	  			if (eThis.hasResultValues(val, expansionVarNames)) {
	  				var o = val["o"]["value"];
	  				var p1 = val["p1"]["value"];
	  				var o1 = val["o1"]["value"];
	  				htmlLine = "<div class='row'><div class='col'>" + o + "</div><div class='col'>" + p1 + "</div><div class='col'>" + o1 + "</div></div>" ;
	  			}
	  			return htmlLine;
	  		});
	  		$("#expandstatements").removeClass("d-none");
	  		$("#expandstatements").append(displayHTML.join(" "));

	  		this.triples = this.triples.concat(this.generateTriplesData(bindings, "expansion"));
	  		//this.updateVisualization(bindings, "object");
	  		//Add to graph
	  		this.addToGraph(this.triples);
	  	}
	  }
	  
	  
	  
	  //Triple handling for graph visualization
	  
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

	  	} else if(dataType == "expansion") {
	  		var expansionVarNames = ["o", "p1", "o1"];
	  		triples = $.map(bindings, function(val, i) { 
	  			if (eThis.hasResultValues(val, expansionVarNames)) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var o = val["o"]["value"];
	  				var p1 = val["p1"]["value"];
	  				var o1 = val["o1"]["value"];
	  				return {"subject": o, "predicate": p1, "object": o1}
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
	  
	  //Event handling
	  bindEventHandlers() {
	  	var eThis = this;
	  	$("#expandgraph").click(function(e) {
	  		eThis.getExpandedInfo();
	  	});
	  }
	  
}

$( document ).ready(function() {
    var fusekiURL = configProps["fusekiURL"];
	var viewObj = new ViewEntity(fusekiURL);
	viewObj.init();
});