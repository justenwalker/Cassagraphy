// Script goes below...

(function(){
	var ui = {
		items: null,
		init: function() {
			ui.items = new Array();
			$('.content').each(function(i,e){
				$(e).die('click').live('click',ui.toggle(e))
				ui.items.push(e);
			});
			$('#expandall').die('click').live('click',ui.expandall);
			$('#hideall').die('click').live('click',ui.hideall);
		},
		toggle: function(e) {
			$(e).prev('legend').children('button.hide').each(function(i,a){
				$(a).die('click').live('click',function(){
					if($(e).hasClass('folded')) {
						ui.expand(e);
					} else {
						ui.hide(e);
					}
				});
			});
		},
		expand: function(e) {
			$(e).removeClass('folded').slideDown();
			$(e).prev('legend').children('button.hide').addClass('minus').removeClass('plus');
		},
		hide: function(e) {
			$(e).addClass('folded').slideUp();
			$(e).prev('legend').children('button.hide').addClass('plus').removeClass('minus');
		},
		expandall: function() {
			$.each(ui.items,function(i,item) {
				ui.expand(item);
			});
		},
		hideall: function() {
			$.each(ui.items,function(i,item) {
				ui.hide(item);
			});
		}
	};
	$(document).ready(function(){
		console.log('ready');
		ui.init();
	});
})();