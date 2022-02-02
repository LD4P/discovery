
function filterNodesById(nodes,id){
	return nodes.filter(function(n) { return n.id === id; });
}

function triplesToGraph(triples){

	svg.html("");
	//Graph
	var graph={nodes:[], links:[]};
	
	//Initial Graph from triples
	triples.forEach(function(triple){
		var subjId = triple.subject;
		var predId = triple.predicate;
		var objId = triple.object;
		
		var subjNode = filterNodesById(graph.nodes, subjId)[0];
		var objNode  = filterNodesById(graph.nodes, objId)[0];
		//label was subjId, but we're changing it
		var subjLabel = shortenDisplayURI(subjId);
		var objLabel = shortenDisplayURI(objId);
		var predLabel = shortenDisplayURI(predId);
		if(subjNode==null){
			subjNode = {id:subjId, label:subjLabel, weight:1};
			graph.nodes.push(subjNode);
		}
		
		if(objNode==null){
			objNode = {id:objId, label:objLabel, weight:1, isURI:isURI(objId)};
			graph.nodes.push(objNode);
		}
	
		
		graph.links.push({source:subjNode, target:objNode, predicate:predLabel, predUri:predId, weight:1});
	});
	
	return graph;
}

//Own function to get label for URI
function shortenDisplayURI(val) {
	var returnVal = val;
	//Shorten namespaces
	/*
	var namespaces = {
		"http://id.loc.gov/ontologies/bibframe/":"bf:",
		"http://www.w3.org/1999/02/22-rdf-syntax-ns#":"rdf:",
		"http://id.loc.gov/ontologies/bflc/":"bflc:",
		"https://svde.org/": "svde:"
	};
	*/
	//Only return things that start with http:// or https://, gets rid of literals
	//Use only local names to shorten display
	if(isURI(val)) {
		var separator = (val.indexOf("#") > -1)? "#" : "/";
		var lastIndex= val.lastIndexOf(separator);
		returnVal = val.slice(lastIndex + 1, val.length);
		
	} else {
		returnVal = (returnVal.length > 15) ? returnVal.substring(0, 15): returnVal;
	}
	return returnVal;
}

function isURI(val) {
	return val.startsWith("http://") || val.startsWith("https://");
}

//https://gist.github.com/jpmarindiaz/6543884
function addTooltip(circle) {
    var x = parseFloat(circle.attr("cx"));
    var y = parseFloat(circle.attr("cy"));
    var r = parseFloat(circle.attr("r"));
    console.log(x);
    console.log(y);
    console.log(r)
    var text = circle.attr("id");
	console.log(text);
    var tooltip = svg
        .append("text")
        .text(text)
        .attr("x", x)
        .attr("y", y)
        .attr("dy", -r * 2)
        .attr("id", "tooltip")
        .style("fill", function (d) { return '#1f77b4'; });

    var offset = tooltip.node().getBBox().width / 2;
	//Added
	var width= svg.attr("width");
	var height = svg.attr("height");
	var margin = 20;
	//Was just -r,r, and 0
	var gap = 150;
    if ((x - offset) < 0) {
        tooltip.attr("text-anchor", "start");
        tooltip.attr("dx", -r + gap);
    }
    else if ((x + offset) > (width - margin)) {
        tooltip.attr("text-anchor", "end");
        tooltip.attr("dx", r + gap);
    }
    else {
        tooltip.attr("text-anchor", "middle");
        tooltip.attr("dx", gap);
    }
}

//Add hover
function addHoverHandler() {
	 svg.selectAll(".node,.link")
		.on("mouseover", function() {
		      var sel = d3.select(this);
		       sel.classed("hovered",true);
		       addTooltip(sel);
		    })
		.on("mouseout", function() {
		      var sel = d3.select(this);
		       sel.classed("hovered",false);
		       d3.select("#tooltip").remove();
		    });  
}

function update(){
	// ==================== Add Marker ====================
	svg.append("svg:defs").selectAll("marker")
	    .data(["end"])
	  .enter().append("svg:marker")
	    .attr("id", String)
	    .attr("viewBox", "0 -5 10 10")
	    .attr("refX", 30)
	    .attr("refY", -0.5)
	    .attr("markerWidth", 6)
	    .attr("markerHeight", 6)
	    .attr("orient", "auto")
	  .append("svg:polyline")
	    .attr("points", "0,-5 10,0 0,5")
	    ;
		
	// ==================== Add Links ====================
	var links = svg.selectAll(".link")
						.data(graph.links)
						.enter()
						.append("line")
							.attr("marker-end", "url(#end)")
							.attr("class", "link")
							.attr("stroke-width",1)
					;//links
	
	// ==================== Add Link Names =====================
	var linkTexts = svg.selectAll(".link-text")
                .data(graph.links)
                .enter()
                .append("text")
					.attr("class", "link-text")
					.text( function (d) { return d.predicate; })
				;

		//linkTexts.append("title")
		//		.text(function(d) { return d.predicate; });
				
	// ==================== Add Link Names =====================
	var nodeTexts = svg.selectAll(".node-text")
                .data(graph.nodes)
                .enter()
                .append("text")
					.attr("class", "node-text")
					.text( function (d) { return d.label; })
				;

		//nodeTexts.append("title")
		//		.text(function(d) { return d.label; });
	
	// ==================== Add Node =====================
	var nodes = svg.selectAll(".node")
						.data(graph.nodes)
						.enter()
						.append("circle")
							.attr("class", "node")
							.attr("r",8)
							.call(force.drag)
							.attr("id", function(d, i) { return d.id; })
							.on("mouseover", function(d, i) { addTooltip(d3.select(this)); })
        					.on("mouseout",  function(d, i) { d3.select("#tooltip").remove(); });
					;//nodes
			//Added mouseover and mouseout for hover from other stuff		

	// ==================== Force ====================
	force.on("tick", function() {
		nodes
			.attr("cx", function(d){ return d.x; })
			.attr("cy", function(d){ return d.y; })
			;
		
		links
			.attr("x1", 	function(d)	{ return d.source.x; })
	        .attr("y1", 	function(d) { return d.source.y; })
	        .attr("x2", 	function(d) { return d.target.x; })
	        .attr("y2", 	function(d) { return d.target.y; })
	       ;
		   
		nodeTexts
			.attr("x", function(d) { return d.x + 12 ; })
			.attr("y", function(d) { return d.y + 3; })
			;
			

		linkTexts
			.attr("x", function(d) { return 4 + (d.source.x + d.target.x)/2  ; })
			.attr("y", function(d) { return 4 + (d.source.y + d.target.y)/2 ; })
			;
	});
	
	// ==================== Run ====================
	force
      .nodes(graph.nodes)
      .links(graph.links)
	  .charge(-500)
	  .linkDistance(300)
      .start()
	  ;
	  //Changed link distance to 500 from 100
	  
	  //Add event handlers
	  addHoverHandler();
}

