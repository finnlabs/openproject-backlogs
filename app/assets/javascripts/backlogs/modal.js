/*jslint indent: 2, regexp: false */
/*globals $, Control, Element, Class, Event, window, setTimeout */
/*globals console */
var Backlogs = (function () {
  var Modal, ModalLink, width;

  width = function () {
    var max = 800;

    if (window.document.viewport.getWidth() < max) {
      return max - 100;
    }
    else {
      return max;
    }
  };

  Modal = Class.create(Control.Modal, {
    initialize : function ($super, container, options) {
      Modal.InstanceMethods.beforeInitialize.bind(this)();
      $super(container, Object.extend(Object.clone(Modal.defaultOptions), options || {}));
    },

    position : function ($super, event) {
      $super(event);
      this.fixPosition();
    },

    ensureInBounds : function ($super) {
      $super();
      this.fixPosition();
    },

    fixPosition : function () {
      var currentTop = this.container.getStyle('top');
      if (currentTop && currentTop.replace(/[^\d]*/g, '') === '0') {
        this.container.setStyle({top: (window.document.viewport.getScrollOffsets().top + 50) + 'px'});
      }
    }
  });

  Object.extend(Modal, {
    defaultOptions : {
      overlayOpacity: 0.75,
      method:    'get',
      className: 'modal',
      fade:      true,
      position:  'center_once',
      width :    width
    },

    Observers : {
      beforeOpen : function () {
        var closeButton = new Element('div', {'id' : 'livepipe-modal-closer'});

        this.container.appendChild(closeButton);
        closeButton.observe('click', function () {
          if (Control.Modal.current) {
            Control.Modal.current.close();
          }
        });
      },
      onError : function (klass, error) {
        this.isOpen = true; // assume, we are open, otherwise, we cannot be closed.
        this.close();
        this.remoteContentLoaded = false;
      },
      afterClose : function () {
        if (this.container.children.length > 0) {
          this.remoteContentLoaded = false;
          this.container.innerHTML = "";
        }
      }
    },

    InstanceMethods : {
      beforeInitialize : function () {
        this.observe('beforeOpen', Modal.Observers.beforeOpen.bind(this));
        this.observe('onFailure',  Modal.Observers.onError.bind(this));
        this.observe('afterClose', Modal.Observers.afterClose.bind(this));
      }
    }
  });

  ModalLink = Class.create({
    initialize : function (element) {
      this.observeMouseOver(element);
    },

    observeMouseOver : function (element) {
      this.element = $(element);
      this.handler = this.handleMouseOver.bind(this);
      this.element.observe('mouseover', this.handler);
    },

    handleMouseOver : function (e) {
      var modal;
      this.element.stopObserving('mouseover', this.handler);
      modal = new Modal(this.element);
    }
  });

  Control.Window.baseZIndex = 50;
  Control.Overlay.styles.zIndex = 49;
  Control.Overlay.ieStyles.zIndex = 49;
  // should fix overlay not extending till the very base of the modal window
  Control.Overlay.ieStyles.position = 'fixed';
  return {
    Modal : Modal,
    ModalLink : ModalLink
  };
}());
