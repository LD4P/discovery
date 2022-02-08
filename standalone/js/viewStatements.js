	class ViewStatements {
	
	  constructor(fusekiURL) {
	  	this.fusekiURL = fusekiURL;
	  }
	  init() {
	  	this.initURI();
	  	this.updateHeading();
	  	this.getStatements();
	  }
	  
	  initURI() {
	  	this.uri= this.getUrlParameter("uri");
	  	this.type = this.getUrlParameter("type");
	  }
	  
	  updateHeading() {
	  	$("#pageheading").append(" " + this.uri);
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
	
	getStatements() {
		//Types = subject or predicate
		if(this.type == "subject") {
			this.executeQuery(this.getAsSubjectQuery(this.uri), this.displayStatementsAsSubject.bind(this));
		}
		if(this.type == "predicate") {
			this.executeQuery(this.getWithPredicateQuery(this.uri), this.displayStatementsWithPredicate.bind(this));
		}

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
	  //Get statements where the subject is of type represented by URI
	  //Building in limit now but can make this configurable later
	  getAsSubjectQuery(typeURI) {
	  	return this.getPrefixes() + "SELECT ?s ?p ?o  WHERE {?s rdf:type <"+ typeURI + "> . ?s ?p ?o .} LIMIT 100";
	  }
	  
	   getWithPredicateQuery(predicateURI) {
	  	return this.getPrefixes() + "SELECT ?s ?o  WHERE {?s <" + predicateURI + "> + ?o .} LIMIT 100";
	  }
	  
	
	  
	  //Display methods
	  //Classes
	  displayStatementsAsSubject(data) {
	    var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			if (val && "s" in val && "value" in val["s"] 
	  			&& "p" in val && "value" in val["p"] 
	  			&& "o" in val && "value" in val["o"]) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var s = val["s"]["value"];
	  				var p = val["p"]["value"];
	  				var o = val["o"]["value"];
	  				var sLink = "viewEntity.html?uri=" + s;
	  				$("#statements").append("<div class='row'><div class='col'><a href='" + sLink + "'>" + s + "</a></div><div class='col'>" + p + "</div><div class='col'>" + o + "</div></div>" );
	  			}
	  		});
	  	}
	  }
	  
	   displayStatementsWithPredicate(data) {
	    var eThis = this;
	  	if("results" in data && "bindings" in data["results"] && data["results"]["bindings"].length) {
	  		//Map bindings to html
	  		var bindings = data["results"]["bindings"];
	  		var displayHTML = $.map(bindings, function(val, i) { 
	  			if (val && "s" in val && "value" in val["s"] 
	  			&& "o" in val && "value" in val["o"]) {
	  				//return eThis.displayIndividualClass(val["type"]["value"]);
	  				var p = val["s"]["value"];
	  				var o = val["o"]["value"];
	  				$("#statements").append("<div class='row'><div class='col'>" + s + "</div><div class='col'>" + o + "</div></div>" );
	  			}
	  		});
	  	}
	  }
	  
	
	
	  
}

$( document ).ready(function() {
    var fusekiURL = configProps["fusekiURL"];
	var viewObj = new ViewStatements(fusekiURL);
	viewObj.init();
});