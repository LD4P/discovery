var processWikidata = {
  onLoad: function() {
      this.bindEventHandlers();
  },

  bindEventHandlers: function() {
    $('*[data-wikiload]').click(function() {
      var e=$(this);
//      e.off('click');
      var wikidataEndpoint = "https://query.wikidata.org/sparql?";
      var workId = e.data('wikiload');
      var sparqlQuery = "SELECT ?entity WHERE {?entity wdt:P5331 \"" + workId + "\"}";
      $.ajax({
        url : wikidataEndpoint,
        headers : {
          Accept : 'application/sparql-results+json'
        },
        data : {
          query : sparqlQuery
        },
        success : function(data) {
          if ( data['results']['bindings'].length ) {
            processWikidata.getWikiEntity(data['results']['bindings'][0]['entity']['value']);
          } 
          else {
            console.log("woe is me");
          }
        }
      });
    });
  },
  getWikiEntity: function(uri) {
    var localName = uri.split("/").pop();
    $.ajax({
      url : "https://www.wikidata.org/wiki/Special:EntityData/" + localName + ".json",
      dataType : "json",
      complete: function(xhr, status) {
        var response = xhr.responseJSON['entities'];
        console.log("Wikidata = " + response.toSource());
      } 
    });
  }
};  
Blacklight.onLoad(function() {
  processWikidata.onLoad();  
});  
