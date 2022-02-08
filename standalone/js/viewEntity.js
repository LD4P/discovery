	class ViewEntity {
	
	  constructor(fusekiURL) {
	  	this.fusekiURL = fusekiURL;
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
			this.executeQuery(this.getSubjectQuery(this.uri), this.displaySubjectInfo.bind(this));
			this.executeQuery(this.getObjectQuery(this.uri), this.displayObjectInfo.bind(this));

		}
	  //Execute query against Fuseki
	  //callbackData is an object you can send with values in case the specific callback function needs to employ additional info
	  executeQuery(query, callback, callbackData) {
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
	  		this.generateTriplesData(bindings, "subject");
	  	}
	  }
	  
	  displayObjectInfo(data) {
	    var eThis = this;
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
	  		
	  	}

	  }
	  
	  //Generate data as triples, convert to JSON string, and make graph
	  generateTriplesData(bindings, dataType) {
	  	//if as subject
	  	var eThis = this;
	  	if(dataType == "subject") {
	  		var asSubjectTriples = $.map(bindings, function(val, i) { 
	  			if (val && "p" in val && "value" in val["p"] 
	  			&& "o" in val && "value" in val["o"]) {
	  				var p = val["p"]["value"];
	  				var o = val["o"]["value"];
	  				return {"subject": eThis.uri, "predicate": p, "object": o}
	  			}
	  		});
	  		$("#sdata").val(JSON.stringify(asSubjectTriples));

	  	}
	  	//if as object
	  }
	  
	
	  
}

$( document ).ready(function() {
    var fusekiURL = configProps["fusekiURL"];
	var viewObj = new ViewEntity(fusekiURL);
	viewObj.init();
});