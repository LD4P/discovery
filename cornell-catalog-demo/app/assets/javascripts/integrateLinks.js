//Knowledge Panel JS code

$(document).ready(function () {
  $(this).on('click','*[data-auth]',
      function (event) {
        var e = $(this);
        //e.off('click');
        event.preventDefault();
        // var baseUrl = e.attr("base-url")
        var baseUrl = $("#itemDetails").attr("base-url");
        console.log("base url " + baseUrl);
        var auth = e.attr("data-auth");
        var headingType = e.attr("heading-type");
        console.log("Auth value is " + auth);
        auth = auth.replace(/,\s*$/, "");
        console.log("After replacing comma " + auth);
        // Also periods
        auth = auth.replace(/\.\s*$/, "");
        console.log("Auth after replacing period " + auth);
        var authType = e.attr("data-auth-type");
        console.log("Authorization type is " + authType);
        var catalogAuthURL = e.attr("datasearch-poload");
        // Set up container
        var contentHtml = "<div id='popoverContent' class='kp-content'><div id='authContent'></div><div id='wikidataContent'></div><div id='digitalCollectionsContent'></div></div>";
        //,trigger : 'focus'
        e.popover({
          content : contentHtml,
          html : true,
          trigger: 'click'
        }).popover('show');
        // Get authority content
        $.get(catalogAuthURL, function (d) {
          $("#authContent").append(d);
        });
        locPath = "names";
        rdfType = "PersonalName";
        // Even though LCSH has person names, querying /subjects for
        // names won't get you main resource
        // TODO: look into
        // id.loc.gov/authorities/names/label/[label]
        // for subject, LOC query will replace > with --
        // Digital collections will just use space for now
        var locQuery = auth;
        var digitalQuery = auth;
        if (authType == "subject") {
          if (headingType != "Personal Name") {
            locPath = "subjects";
            rdfType = "(Topic OR rdftype:ComplexSubject)";
          }
          locQuery = locQuery.replace(/\s>\s/g, "--");
          digitalQuery = digitalQuery.replace(/>/g, " ");
        }
        var lookupURL = "http://id.loc.gov/authorities/" + locPath
        + "/suggest/?q=" + locQuery + "&rdftype=" + rdfType
        + "&count=1";
        // Copied from original bfe example

        $.ajax({
          url : lookupURL,
          dataType : 'jsonp',
          success : function (data) {
            urisArray = parseLOCSuggestions(data);
            if (urisArray && urisArray.length) {
              var locURI = urisArray[0]; // Pick
              // first
              // one
              console.log("LOC URI is " + locURI);
              queryWikidata(locURI, e);
            }
          }
        });

        // Add query to lookup digital collections
        searchDigitalCollections(baseUrl, digitalQuery);
      });

  // Function to lookup digital collections
  function searchDigitalCollections(baseUrl, authString) {
    var lookupURL = baseUrl + "proxy/search?q=" + authString;
    $.ajax({
      url : lookupURL,
      dataType : 'json',
      success : function (data) {
        console.log("success querying dig collections");
        console.log(data);
        // Digital collection results, append
        var results = [];
        if ("response" in data && "docs" in data.response) {
          results = data["response"]["docs"];
          // iterate through array
          var resultsHtml = "<div><ul class=\"explist-digitalresults\">";
          var authorsHtml = "<div><ul class=\"explist-digitalcontributers\">";
          var maxLen = 10;
          var len = results.length;
          if (len > maxLen)
            len = maxLen;
          var l;
          for (l = 0; l < len; l++) {
            var result = results[l];
            var id = result["id"];
            var title = result["title_tesim"];
            var digitalURL = "http://digital.library.cornell.edu/catalog/"
              + id;
            resultsHtml += "<li><a href='" + digitalURL + "'>"
            + title + "</a></li>";
            var creator = [], creator_facet = [];
            if ("creator_tesim" in result)
              creator = result["creator_tesim"];
            if ("creator_facet_tesim" in result)
              creator_facet = result["creator_facet_tesim"];
            if (creator.length) {
              var c = creator.length;
              var i;
              for (i = 0; i < creator.length; i++) {
                authorsHtml += "<li><a href='" + baseUrl
                + "catalog?q=" + creator[i]
                + "&search_field=all_fields'>" + creator[i]
                + "</a></li>";
              }
            }
          }

          resultsHtml += "</ul><button id=\"expnext-digitalresults\">&#x25BD; more</button></div>";
          var displayHtml = "<div><h4>Digital Collections Results</h4>"
            + resultsHtml
            + "<h4>Related Digital Collections Contributors</h4>"
            + authorsHtml
            + "</ul><button id=\"expnext-digitalcontributers\">&#x25BD; more</button></div>";
          $("#digitalCollectionsContent").append(displayHtml);
          listExpander('digitalresults');
          listExpander('digitalcontributers');
        }

      }
    });
  }

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
    var sparqlQuery = "SELECT ?entity ?entityLabel WHERE {?entity wdt:P244 \""
      + localname
      + "\" SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". }}";
    $.ajax({
      url : wikidataEndpoint,
      headers : {
        Accept : 'application/sparql-results+json'
      },
      data : {
        query : sparqlQuery
      },
      success : function (data) {
        // Data -> results -> bindings [0] ->
        // entity -> value
        var wikidataParsedData = parseWikidataSparqlResults(data);
        var wikidataURI = wikidataParsedData['uriValue'];
        var authorLabel = wikidataParsedData['authorLabel'];
        // Do a popover here with the wikidata uri and the loc uri
        // if no wikidata uri then will just show null
        var contentHtml = "<section class=\"kp-flexrow\"><figure class=\"kp-entity-image\"></figure><div><h3>"
          + authorLabel
          + "</h3><span class=\"kp-source\">Source: Wikidata</span></div></section>";
        $("#wikidataContent").append(contentHtml);
        // Get notable results
        if (wikidataURI != null) {
          getImage(wikidataURI);
          getNotableWorks(wikidataURI);
          getPeopleInfluencedBy(wikidataURI);
          getPeopleWhoInfluenced(wikidataURI);
        }

      }

    });

  }

  // function to parse sparql query results from wikidata, getting URI
  // and author name
  function parseWikidataSparqlResults(data) {
    output = {}
    if (data && "results" in data && "bindings" in data["results"]) {
      var bindings = data["results"]["bindings"];
      if (bindings.length) {
        var binding = bindings[0];
        if ("entity" in binding && "value" in binding["entity"]) {
          output.uriValue = binding["entity"]["value"];
        }
        if ("entityLabel" in binding
            && "value" in binding["entityLabel"]) {
          output.authorLabel = binding["entityLabel"]["value"];
        }
      }
    }
    return output;
  }

  // function to get localname from LOC URI
  function getLocalName(uri) {
    // Get string right after last slash if it's present
    // TODO: deal with hashes later
    return uri.split("/").pop();
  }

  // Wikidata entity
  function retrieveWikidataEntity(wikidataURI) {

  }

  // Wikidata notable works
  function getNotableWorks(wikidataURI) {
    var wikidataEndpoint = "https://query.wikidata.org/sparql?";
    var sparqlQuery = "SELECT ?notable_work ?title WHERE {<"
      + wikidataURI
      + "> wdt:P800 ?notable_work. ?notable_work wdt:P1476 ?title. ?notable_work wikibase:sitelinks ?linkcount . } ORDER BY DESC(?linkcount)";

    $.ajax({
      url : wikidataEndpoint,
      headers : {
        Accept : 'application/sparql-results+json'
      },
      data : {
        query : sparqlQuery
      },
      success : function (data) {

        console.log("Notable works ");
        console.log(data);
        if (data && "results" in data
            && "bindings" in data["results"]) {
          var bindings = data["results"]["bindings"];
          var bLength = bindings.length;
          var b;
          if (bindings.length) {
            var notableWorksHtml = "<div><h4>Notable Works</h4><ul class=\"explist-notable\"><li>";
            var notableHtmlArray = [];
            for (b = 0; b < bLength; b++) {
              var binding = bindings[b];
              if ("notable_work" in binding
                  && "value" in binding["notable_work"]
              && "title" in binding
              && "value" in binding["title"]) {
                var notableWorkURI = binding["notable_work"]["value"];
                var notableWorkLabel = binding["title"]["value"];
                console.log("uri and label for notable work "
                    + notableWorkURI + ":" + notableWorkLabel);
                notableHtmlArray.push("<a href='" + notableWorkURI
                    + "'>" + notableWorkLabel + "</a>");
              }
            }
            notableWorksHtml += notableHtmlArray.join("</li><li>")
            + "</li></ul><button id=\"expnext-notable\">&#x25BD; more</button></div>";
            $("#wikidataContent").append(notableWorksHtml);
          }
        }
        listExpander('notable');
      }

    });
  }

  // Wikidata people who influenced the current author
  function getPeopleInfluencedBy(wikidataURI) {
    var wikidataEndpoint = "https://query.wikidata.org/sparql?";
    // var sparqlQuery = "SELECT ?influenceFor ?influenceForLabel WHERE
    // {?influenceFor wdt:P737 <" + wikidataURI + "> . SERVICE
    // wikibase:label { bd:serviceParam wikibase:language
    // \"[AUTO_LANGUAGE],en\". } } ORDER BY ASC(?influenceForLabel)";
    var sparqlQuery = "SELECT ?influenceFor ?surname ?givenName ?surnameLabel ?givenNameLabel ( CONCAT(?surnameLabel, \", \" ,?givenNameLabel ) AS ?influenceForLabel ) WHERE { ?influenceFor wdt:P737 <"
      + wikidataURI
      + "> . ?influenceFor wdt:P734 ?surname . ?influenceFor wdt:P735 ?givenName . SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". }} ORDER BY ASC(?surnameLabel)"

      $.ajax({
        url : wikidataEndpoint,
        headers : {
          Accept : 'application/sparql-results+json'
        },
        data : {
          query : sparqlQuery
        },
        success : function (data) {
          if (data && "results" in data
              && "bindings" in data["results"]) {
            var bindings = data["results"]["bindings"];
            var bLength = bindings.length;
            var b;
            if (bindings.length) {
              var notableWorksHtml = "<div><h4>Was influence for</h4><ul class=\"explist-influencedby\"><li>";
              var notableHtmlArray = [];
              for (b = 0; b < bLength; b++) {
                var binding = bindings[b];
                if ("influenceFor" in binding
                    && "value" in binding["influenceFor"]
                && "influenceForLabel" in binding
                && "value" in binding["influenceForLabel"]) {
                  var iURI = binding["influenceFor"]["value"];
                  var iLabel = binding["influenceForLabel"]["value"];
                  notableHtmlArray.push("<a href='iURI'>" + iLabel
                      + "</a>");
                }
              }
              notableWorksHtml += notableHtmlArray.join("</li><li>")
              + "</li></ul><button id=\"expnext-influencedby\">&#x25BD; more</button></div>";
              $("#wikidataContent").append(notableWorksHtml);
            }
          }
          listExpander('influencedby');
        }

      });
  }

  // Wikidata author influenced these people
  function getPeopleWhoInfluenced(wikidataURI) {
    var wikidataEndpoint = "https://query.wikidata.org/sparql?";
    // var sparqlQuery = "SELECT ?influencedBy ?influencedByLabel WHERE
    // {<" + wikidataURI + "> wdt:P737 ?influencedBy . SERVICE
    // wikibase:label { bd:serviceParam wikibase:language
    // \"[AUTO_LANGUAGE],en\". } } ORDER BY ASC(?influencedByLabel)";
    var sparqlQuery = "SELECT ?influencedBy ?surname ?givenName ?surnameLabel ?givenNameLabel ( CONCAT(?surnameLabel, \", \" ,?givenNameLabel ) AS ?influencedByLabel ) WHERE { <"
      + wikidataURI
      + "> wdt:P737 ?influencedBy . ?influencedBy wdt:P734 ?surname . ?influencedBy wdt:P735 ?givenName . SERVICE wikibase:label { bd:serviceParam wikibase:language \"[AUTO_LANGUAGE],en\". }} ORDER BY ASC(?surnameLabel)"

      $.ajax({
        url : wikidataEndpoint,
        headers : {
          Accept : 'application/sparql-results+json'
        },
        data : {
          query : sparqlQuery
        },
        success : function (data) {
          if (data && "results" in data
              && "bindings" in data["results"]) {
            var bindings = data["results"]["bindings"];
            var bLength = bindings.length;
            var b;
            if (bindings.length) {
              var notableWorksHtml = "<div><h4>Was influenced by</h4><ul class=\"explist-whoinfluenced\"><li>";
              var notableHtmlArray = [];
              for (b = 0; b < bLength; b++) {
                var binding = bindings[b];
                if ("influencedBy" in binding
                    && "value" in binding["influencedBy"]
                && "influencedByLabel" in binding
                && "value" in binding["influencedByLabel"]) {
                  var iURI = binding["influencedBy"]["value"];
                  var iLabel = binding["influencedByLabel"]["value"];
                  notableHtmlArray.push("<a href='iURI'>" + iLabel
                      + "</a>");
                }
              }
              notableWorksHtml += notableHtmlArray.join("</li><li>")
              + "</li></ul><button id=\"expnext-whoinfluenced\">&#x25BD; more</button></div>";
              $("#wikidataContent").append(notableWorksHtml);
            }
          }
          listExpander('whoinfluenced');
        }

      });
  }

  // Get Image
  function getImage(wikidataURI) {
    var wikidataEndpoint = "https://query.wikidata.org/sparql?";
    var sparqlQuery = "SELECT ?image WHERE {<" + wikidataURI
    + "> wdt:P18 ?image . }";

    $.ajax({
      url : wikidataEndpoint,
      headers : {
        Accept : 'application/sparql-results+json'
      },
      data : {
        query : sparqlQuery
      },
      success : function (data) {

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
            if ("image" in binding && "value" in binding["image"]) {
              var image = binding["image"]["value"];
              $(".kp-entity-image").append(
                  "<img src='" + image + "'>");

            }
          }

        }
      }

    });
  }

});

//Workings of "show more" links on knowledge panel lists
function listExpander(domString) {
  var list = $(".explist-" + domString + " li");
  var numToShow = 3;
  var button = $("#expnext-" + domString);
  var numInList = list.length;
  list.hide();
  if (numInList > numToShow) {
    button.show();
  }
  list.slice(0, numToShow).show();

  button.click(function () {
    var showing = list.filter(':visible').length;
    list.slice(showing - 1, showing + numToShow).fadeIn();
    var nowShowing = list.filter(':visible').length;
    if (nowShowing >= numInList) {
      button.hide();
    }
  });
};

//Close popover when clicking outside
//TODO: Native popover functionality should allow for closing when clicking on the X and when clicking outside
//How has this been overridden and how can we maintain it?
$(document).mouseup(function (e) {
  var container = $(".popover");
  if (!container.is(e.target) && container.has(e.target).length === 0) {
    container.popover("hide");
  }
});
