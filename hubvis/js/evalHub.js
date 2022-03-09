/*
* List unique ISBNS for every hub that has > 1 work
*/

class evalHub {

    constructor(displayDiv) {
        this.displayDiv = displayDiv;
        this.requestType = null;
        this.requestQuery = null;
        //Save data to generate tree later
        //Structure slightly different
        this.data = {};
    }
    parseLOCJSON(uri, LOCJSON) {
        var mainObject = null;
        try {
            $.each(LOCJSON, function (i, v) {
                if ("@id" in v && v["@id"] == uri) {
                    mainObject = v;
                    return false;
                }
            });
        } catch (err) {
            console.log("ERROR in parse loc");
            console.log(err);
            console.log(uri);
            console.log(LOCJSON);
        }
        return mainObject;
    }

    //This uses an instance URI to begin walking up and down the chain to gather information	
    retrieveLOCRelationships(uri) {
        this.retrieveHubForInstance(uri, this.retrieveHubRelationships.bind(this));

    }

    //Save references
    // Parent -> URI for parent, children -> array of URIs for children
    saveTreeReference(uri, parent, children, type) {
        this.data[uri] = {"name": uri, "uri": uri, "parent": parent, "children": children, "type": type};
    }

    saveTreeChildren(uri, children) {
        if(uri in this.data) {
            this.data[uri]["children"] = children;
        }
    }

    //Get a related hub URI, e.g. translation
    retrieveHubRelationships(hubURI) {
        var hubPromise = this.retrieveLOCEntity(hubURI);
        var eThis = this;
        $.when(hubPromise).done(function (data) {
            var mainObject = eThis.parseLOCJSON(hubURI, data);
            //For this hub, get all the works
            console.log("Get main object for " + hubURI);
            console.log(mainObject);
            eThis.retrieveHubDescendants(hubURI, mainObject);
        });
        //Save tree information
        this.saveTreeReference(hubURI, null, [],"hub");

    }

    //Single hub object
    //Compare against any hubs that > 1 work
    retrieveHubDescendants(hubURI, hubInfo) {
        var eThis = this;
        var wpromises = [];
        var wuris = [];

        var worksList = eThis.getRelatedURIFromJSON(hubInfo, "hub", "hasExpression");

        $.each(worksList, function (wi, wval) {
            //Exclude blank nodes
            if ("@id" in wval && wval["@id"] != "" && wval["@id"].startsWith("http://id.loc.gov")) {
                wuris.push(wval["@id"]);
                wpromises.push(eThis.retrieveLOCEntity(wval["@id"]));
                //Save tree information
            }
        })
        if(worksList.length > 0) {
            //update children
            this.saveTreeChildren(hubURI, wuris);
        }
        this.retrieveWorkDescendants(hubURI, wpromises, wuris);


    }

    retrieveWorkDescendants(hubURI, wpromises, wuris) {
        console.log("Retrieve work descendants");
        var eThis = this;
        //For these promises, get work objects - get instances - then get isbns
        $.when.apply($, wpromises).done(function () {
            //Using work JSON ld responses, parse to get the objects representing those work URIs
            var wargs = arguments;
            //console.log(wpromises.length);
            if (wpromises.length == 1) {
                wargs = [arguments];
            }
            var workInfo = $.map(wargs, function (workVal, i) {
                if (workVal && workVal.length) {
                    return eThis.parseLOCJSON(wuris[i], workVal[0]);
                } else {
                    console.log("Error with workval");
                    console.log(workVal);
                }
            });
            var iuris = [];
            var ipromises = [];
            $.each(workInfo, function (i, wJSON) {
                var instancesList = eThis.getRelatedURIFromJSON(wJSON, "work", "hasInstance");
                $.each(instancesList, function (i, ival) {
                    if ("@id" in ival) {
                        iuris.push(ival["@id"]);
                        ipromises.push(eThis.retrieveLOCEntity(ival["@id"]));
                    }
                })
                if(iuris.length > 0) {
                    eThis.saveTreeReference(wJSON["@id"], hubURI, iuris,"work");
                    $.each(iuris, function(i, v) {
                        eThis.saveTreeReference(v, wJSON["@id"], [],"instance");
                    });
                }

            });

            //now, work for instance promises - when you get the objects back, check for isbn OR LCCN values
            $.when.apply($, ipromises).done(function () {
                var lccns = [];
                var isbns = [];
                var iargs = arguments;
                if (ipromises.length == 1) {
                    iargs = [arguments];
                }
                $.each(iargs, function (i, instanceVal) {
                    if (instanceVal && instanceVal.length > 0) {
                        //this includes instance info as well as related bnodes, etc.
                        var instanceResultJSON = instanceVal[0];
                        var instanceURI = iuris[i];
                        var instanceJSON = eThis.parseLOCJSON(instanceURI, instanceResultJSON);
                        var idProp = "http://id.loc.gov/ontologies/bibframe/identifiedBy";
                        var lccnType = "http://id.loc.gov/ontologies/bibframe/Lccn";
                        var isbnType = "http://id.loc.gov/ontologies/bibframe/Isbn";
                        var rdfValue = "http://www.w3.org/1999/02/22-rdf-syntax-ns#value";
                        var instanceISBNs = [];
                        //Add this to the tree data
                        //First, check if identifiedBy exists
                        if (idProp in instanceJSON && instanceJSON[idProp].length > 0) {
                            var identifiedArray = instanceJSON[idProp];
                            $.each(identifiedArray, function (index, idv) {
                                if ("@id" in idv) {
                                    var bnode = idv["@id"];
                                    //Now check the full result JSON for this bnode
                                    var bnodeInfo = eThis.parseLOCJSON(bnode, instanceResultJSON);
                                    if (bnodeInfo != null) {
                                        //Check type
                                        if ("@type" in bnodeInfo && bnodeInfo["@type"].length > 0 && bnodeInfo["@type"][0] == lccnType) {
                                            var idValObjs = bnodeInfo[rdfValue];
                                            $.each(idValObjs, function (ioi, iov) {
                                                lccns.push($.trim(iov["@value"]));
                                            });
                                        }
                                        //Check for ISBN
                                        if ("@type" in bnodeInfo && bnodeInfo["@type"].length > 0 && bnodeInfo["@type"][0] == isbnType) {
                                            var idValObjs = bnodeInfo[rdfValue];
                                            $.each(idValObjs, function (ioi, iov) {
                                                var isbnValue = $.trim(iov["@value"]);
                                                isbns.push(isbnValue);
                                                //Associate this with the instance ID
                                                instanceISBNs.push(isbnValue);
                                            });
                                        }
                                    }
                                }
                            });
                        }
                        if(instanceISBNs.length > 0) {
                            //eThis.saveTreeReference(wJSON["@id"], hubURI, iuris,"work");
                            eThis.saveTreeChildren(instanceURI, instanceISBNs);
                        }

                    }
                });
                //console.log(lccns.join(" OR "));
                //console.log(isbns.join(" OR "));
                if (isbns.length > 0) {
                    console.log("ISBNs found");
                    //Directly output the ISBNs
                    //$("#isbnsets").append(hubURI + "," + isbns.join(",") + "<br/>");
                    //eThis.retrieveDirectLookup("isbn", isbns);
                }
                //if(lccns.length > 0) {
                //	eThis.retrieveDirectLookup("lccn", lccns);
                //}


            });

        });



    }


    //Given an LOC JSON object, retrieve specific uris
    //Returns array for properties
    //example: mainObject, "instance", "instanceOf" i.e. if object is an instance, what is it an instance of
    getRelatedURIFromJSON(mainObject, classType, relationship) {
        var returnValues = [];
        var classHash = {
            "instance": "http://id.loc.gov/ontologies/bibframe/Instance",
            "work": "http://id.loc.gov/ontologies/bibframe/Work",
            "hub": "http://id.loc.gov/ontologies/bibframe/Hub"
        };
        var propertyHash = {
            "instanceOf": "http://id.loc.gov/ontologies/bibframe/instanceOf",
            "expressionOf": "http://id.loc.gov/ontologies/bibframe/expressionOf",
            "hasTranslation": "http://id.loc.gov/ontologies/bibframe/translation",
            "hasExpression": "http://id.loc.gov/ontologies/bibframe/hasExpression",
            "hasInstance": "http://id.loc.gov/ontologies/bibframe/hasInstance",
            "partOf": "http://id.loc.gov/ontologies/bibframe/partOf",
            "relatedTo": "http://id.loc.gov/ontologies/bibframe/relatedTo",
            "hasPart": "http://id.loc.gov/ontologies/bibframe/hasPart",
            "hasSeries": "http://id.loc.gov/ontologies/bibframe/hasSeries",
            "translationOf": "http://id.loc.gov/ontologies/bibframe/translationOf"
        }

        //get the work for an instance

        if (this.jsonIsType(mainObject, classHash[classType])) {
            var prop = propertyHash[relationship];
            if (prop in mainObject && mainObject[prop].length > 0) {
                returnValues = mainObject[prop];
            }
        }
        return returnValues;
    }

    //Return a promise
    retrieveLOCEntity(uri) {
        var eThis = this;
        return $.ajax({
            url: uri.replace("http:", "https:") + ".json",
            "uri": uri,
            context: this
        });

    }

    jsonIsType(json, uriType) {
        if ("@type" in json && json["@type"].length > 0) {
            var types = json["@type"];
            var isType = false;
            $.each(types, function (i, v) {
                if (v == uriType) {
                    isType = true;
                    return false;
                }
            });
            return isType;
        }
        return false;
    }

    getInstanceLink(v) {
        var instanceLink = null;
        $.each(v, function (key, value) {
            if (Array.isArray(value) && value[0] == "atom:link" && (!("type" in value[1]))) {
                instanceLink = value[1]["href"];
                return false;
            }
        });
        return instanceLink;
    }


    //Instead of querying the catalog, let's get the HUBs list directly and use that to get ISBN sets
    //We will then query against the catalog with those ISBN sets to get 
    queryLOCForHubs() {
        var start = parseInt(this.start) > 0 ? "&start=" + this.start : "";
        var url = "https://id.loc.gov/search/?q=cs:http://id.loc.gov/resources/hubs&count=" + this.sampleSize + start + "&format=json";
        var eThis = this;
        $.ajax({
            url: url,
            context: this
        }).done(function (atomData) {
            var hubURIs = [];
            $.each(atomData, function (i, v) {
                if (v !== null && Array.isArray(v) && v.length > 0 && v[0] == "atom:entry") {
                    var hubURI = eThis.getHubURI(v);
                    if (hubURI != null) {
                        hubURIs.push(hubURI.replace("info:lc/", "http://id.loc.gov/"));
                    }
                }
            });
            //Print out hubs
            console.log("Beginning processing of querying for hubs");
            console.log(hubURIs);
            //Generate HUB promises
            eThis.generateHubRequests(hubURIs);
        });

    }

    //we need to change this b/c when done means that if any of the calls fail, this will not work
    generateHubRequests(hubURIs) {
        var eThis = this;
        var hubPromises = $.map(hubURIs, function (v, i) {
            console.log("Generating LOC entity lookup for hub " + v);
            return eThis.retrieveLOCEntity(v);
        });
        //Many hub promises
        //Cannot do a full "when" done, b/c if any one of these fails, none of them are returned
        //Todo: find a better way

        $.each(hubPromises, function (i, h) {
            $.when(h).done(function (data) {
                var hubURI = hubURIs[i];
                var mainObject = eThis.parseLOCJSON(hubURI, data);
                eThis.retrieveHubDescendants(hubURI, mainObject);
            }).fail(function (jqXHR, textStatus) {
                console.log("Error in retrieving hub");
                console.log(textStatus);
            });
        });

        //original way
        /*
        $.when.apply($, hubPromises).done(function() {
            console.log("hub promises are done");
            $.each(arguments, function(i, hubData) {
                var hubURI = hubURIs[i];
                console.log(hubURI);
                console.log(hubData);
                var mainObject = eThis.parseLOCJSON(hubURI, hubData[0]);
                //For this hub, get all the works
                eThis.retrieveHubDescendants(hubURI, mainObject);
            });
        });*/
    }

    getHubURI(entry) {
        var id = null;
        $.each(entry, function (i, v) {
            if (v[0] == "atom:id" && v.length > 1) {
                id = v[2];
                return false;
            }
        });
        return id;
    }

    bindEventListeners() {
        var eThis = this;
        $("#draw").click(function(e) {
            console.log("Click draw");
            eThis.generateTree();
        });
    }

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

    //Handle request
    handleRequest() {
        //Get the type of request and the url
        //Types = HUB which demands hub URI and ISBN which will generate the tree for the ISBN
        this.requestType = this.getUrlParameter("type");
        this.requestQuery = this.getUrlParameter("query");
        if (this.requestType == "hub" && this.requestQuery) {
            //request query is the hub URI
            //URI example: http://id.loc.gov/resources/hubs/c849be15-1883-b9ce-dfee-d72660832de2
            console.log("Request HUB " + this.requestQuery);
            this.retrieveHubRelationships(this.requestQuery);
        } else if (this.requestType == "isbn" && this.requestQuery) {
            //lookup ISBN, get instance, and then work way up the chain
        }


    }
    //Initialize

    init() {

        this.handleRequest();
        this.bindEventListeners();
    }

    /**Tree drawing functions */
    //Get tree data
    generateTreeData() {
        /*
        var treeData = {
            "name": "Top Level",
            "parent": "null",
            "children": [
            {
                "name": "Level 2: A",
                "parent": "Top Level",
                "children": [
                {
                    "name": "Son of A",
                    "parent": "Level 2: A"
                },
                {
                    "name": "Daughter of A",
                    "parent": "Level 2: A"
                }
                ]
            },
            {
                "name": "Level 2: B",
                "parent": "Top Level"
            }
            ]
        };*/
        var treeData = {};
        //Top level is main hub
        console.log("What data looks like");
        console.log(this.data);
        var eThis = this;
        var hub = this.data[this.requestQuery];
        console.log("Hub info from data");
        console.log(hub);
        treeData["name"] = hub["name"];
        treeData["parent"] = null;
        treeData["children"] = [];
        $.each(hub["children"], function(i,v) {
            //treeData["children"].push
            var workObject = {"name": v, "parent": hub["name"], "type": "work", "children":[]};
            //For each work get instances if they exist
            if(v in eThis.data && "children" in eThis.data[v] && eThis.data[v]["children"].length > 0) {
                $.each(eThis.data[v]["children"], function(j,instance) {
                    //Does instance have ISBN, would check here and generate object
                    var isbns = [];
                    if(instance in eThis.data && "children" in eThis.data[instance] && eThis.data[instance]["children"].length > 0) {
                        $.each(eThis.data[instance]["children"], function(k, isbnVal) {
                            isbns.push({"name":isbnVal, "parent":instance});
                        });
                    }
                    var instanceObject = {"name": instance, "parent": v,"type": "instance", "children":isbns};
                    workObject["children"].push(instanceObject);
                });
            }
            treeData["children"].push(workObject);
        });
          return treeData;

    }
    //Generate tree diagram
    generateTree() {
        var treeData = this.generateTreeData();
        // ************** Generate the tree diagram	 *****************
        var margin = {top: 40, right: 120, bottom: 20, left: 120},
        width = 960 - margin.right - margin.left,
        height = 500 - margin.top - margin.bottom;
    
        var i = 0;

        var tree = d3.layout.tree()
            .size([height, width]);

        var diagonal = d3.svg.diagonal()
            .projection(function(d) { return [d.x, d.y]; });

        var svg = d3.select("body").append("svg")
            .attr("width", width + margin.right + margin.left)
            .attr("height", height + margin.top + margin.bottom)
        .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

        //var root = treeData;
        
        this.updateTree(treeData, tree, svg, diagonal, i);
    }
    updateTree(root, tree, svg, diagonal, i) {
    
        // Compute the new tree layout.
        var nodes = tree.nodes(root).reverse(),
            links = tree.links(nodes);
      
        // Normalize for fixed-depth.
        nodes.forEach(function(d) { d.y = d.depth * 100; });
      
        // Declare the nodes…
        var node = svg.selectAll("g.node")
            .data(nodes, function(d) { return d.id || (d.id = ++i); });
      
        // Enter the nodes.
        var nodeEnter = node.enter().append("g")
            .attr("class", "node")
            .attr("transform", function(d) { 
                return "translate(" + d.x + "," + d.y + ")"; });
      
        nodeEnter.append("circle")
            .attr("r", 10)
            .style("fill", "#fff");
      
        nodeEnter.append("text")
            .attr("y", function(d) { 
                return d.children || d._children ? -18 : 18; })
            .attr("dy", ".35em")
            .attr("text-anchor", "middle")
            .text(function(d) { return d.name; })
            .style("fill-opacity", 1);
      
        // Declare the links…
        var link = svg.selectAll("path.link")
            .data(links, function(d) { return d.target.id; });
      
        // Enter the links.
        link.enter().insert("path", "g")
            .attr("class", "link")
            .attr("d", diagonal);
      
      }
}

$(document).ready(function () {
    //try to go up to 300,000
    var r = new evalHub($("#evalHub"));
    r.init();
});

