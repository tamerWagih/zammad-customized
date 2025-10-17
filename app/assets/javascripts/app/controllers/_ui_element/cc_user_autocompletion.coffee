# coffeelint: disable=camel_case_classes
class App.UiElement.cc_user_autocompletion
  @render: (attribute, params = {}) ->
    new App.CcUserAutocompletion(attribute: attribute, params: params).element()
