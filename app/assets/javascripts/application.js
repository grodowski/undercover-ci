// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//= require activestorage
//= require turbolinks

//= require jquery3
//= require bootstrap-sprockets
//= require popper

//= require_tree .

$(document).on("turbolinks:load", function() {
  $(".row-href").click(function() {
      window.location = $(this).data("href");
  });
});

// refresh page when Gumroad iframe modal closes
var gumroadSaleData = null;
var gumroadOnCloseListener = function(e) {
  if (e.origin !== "https://gumroad.com")
    return;

  var data = JSON.parse(e.data);
  if (data.parentMethod === "maximizeIframe") {
    $('a.gumroad-subscribe').addClass("disabled");
  }

  if (data.post_message_name === "sale") {
    gumroadSaleData = data;
  }

  if (data.parentMethod === "minimizeIframe") {
    $('a.gumroad-subscribe').removeClass("disabled");
    if (gumroadSaleData) {
      Turbolinks.visit("/subscription_confirmation");
    }
  }
};
window.addEventListener('message', gumroadOnCloseListener, false);
