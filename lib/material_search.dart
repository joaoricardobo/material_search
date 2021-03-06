import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

typedef String FormFieldFormatter<T>(T v);
typedef bool MaterialSearchFilter<T>(T v, String c);
typedef int MaterialSearchSort<T>(T a, T b, String c);
typedef Future<List<MaterialSearchResult>> MaterialResultsFinder(String c);
typedef void OnSubmit(String value);

class DioParams {
  String url;
  String type;
  String envelope;
  Map<String, String> mapHeaders;
  Map<String, String> mapResults;
  String confirmTitle;
  String confirmMessage;
  String confirmYES;
  String confirmCANCEL;

  DioParams({
    this.url,
    this.type,
    this.envelope,
    this.mapHeaders,
    this.mapResults,
    this.confirmTitle,
    this.confirmMessage,
    this.confirmYES,
    this.confirmCANCEL,
  });
}

class MaterialSearchResult<T> extends StatelessWidget {
  const MaterialSearchResult({
    Key key,
    this.value,
    this.text,
    this.icon,
    this.dioParams,
  }) : super(key: key);

  final T value;
  final String text;
  final IconData icon;
  final DioParams dioParams;

  String getCodeFromString(String sValue) {
    String code = "";
    List<String> list = sValue.split(":");

    if (list.length > 1) {
      code = list[0].trim();
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    IconButton leftIcon = new IconButton(
        icon: new Icon(icon),
        onPressed: () {
          return null;
        });

    if (dioParams != null) {
      leftIcon = new IconButton(
          icon: new Icon(icon),
          color: Colors.red,
          onPressed: () {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                      title: Text(dioParams.confirmTitle),
                      content: Text(dioParams.confirmMessage),
                      actions: <Widget>[
                        new FlatButton(
                            child: new Text(dioParams.confirmYES),
                            onPressed: () async {
                              if (dioParams.type == "POST") {
                                Response response;
                                Dio dio = new Dio();
                                dio.options.headers = dioParams.mapHeaders;

                                String code = getCodeFromString(text);

                                for (var i = 0;
                                    i < dioParams.mapResults.length;
                                    i++) {
                                  if ((i + 1).toString() == code) {
                                    print(text);
                                    dioParams.envelope = dioParams.envelope
                                        .replaceAll(
                                            "##ID##",
                                            dioParams.mapResults.values
                                                .elementAt(i)
                                                .toString());
                                  }
                                }

                                response = await dio.post(dioParams.url, data: {
                                  "envelope": dioParams.envelope
                                }).catchError((error) {
                                  return false;
                                });

                                String result = response.data.toString().trim();
                                result = result;
                                //print(result);
                                Navigator.of(context).pop(); //POPUP CANCEL
                                Navigator.of(context).pop(); //BACK IN SEARCH
                              } else {
                                Navigator.of(context).pop();
                              }
                            }),
                        new FlatButton(
                            child: new Text(dioParams.confirmCANCEL),
                            onPressed: () {
                              Navigator.of(context).pop();
                            }),
                      ]);
                });
          });
    }

    return new Container(
      child: new Row(
        children: <Widget>[
          new Container(width: 70.0, child: leftIcon),
          new Expanded(
              child:
                  new Text(text, style: Theme.of(context).textTheme.subtitle2)),
        ],
      ),
      height: 56.0,
    );
  }
}

class MaterialSearch<T> extends StatefulWidget {
  MaterialSearch({
    Key key,
    this.placeholder,
    this.results,
    this.getResults,
    this.filter,
    this.sort,
    this.limit: 10,
    this.onSelect,
    this.onSubmit,
    this.barBackgroundColor = Colors.white,
    this.iconColor = Colors.black,
    this.leading,
  })  : assert(() {
          if (results == null && getResults == null ||
              results != null && getResults != null) {
            throw new AssertionError(
                'Either provide a function to get the results, or the results.');
          }

          return true;
        }()),
        super(key: key);

  final String placeholder;

  final List<MaterialSearchResult<T>> results;
  final MaterialResultsFinder getResults;
  final MaterialSearchFilter<T> filter;
  final MaterialSearchSort<T> sort;
  final int limit;
  final ValueChanged<T> onSelect;
  final OnSubmit onSubmit;
  final Color barBackgroundColor;
  final Color iconColor;
  final Widget leading;

  @override
  _MaterialSearchState<T> createState() => new _MaterialSearchState<T>();
}

class _MaterialSearchState<T> extends State<MaterialSearch> {
  bool _loading = false;
  List<MaterialSearchResult<T>> _results = [];

  String _criteria = '';
  TextEditingController _controller = new TextEditingController();

  _filter(dynamic v, String c) {
    return v
        .toString()
        .toLowerCase()
        .trim()
        .contains(new RegExp(r'' + c.toLowerCase().trim() + ''));
  }

  @override
  void initState() {
    super.initState();

    if (widget.getResults != null) {
      _getResultsDebounced();
    }

    _controller.addListener(() {
      setState(() {
        _criteria = _controller.value.text;
        if (widget.getResults != null) {
          _getResultsDebounced();
        }
      });
    });
  }

  Timer _resultsTimer;
  Future _getResultsDebounced() async {
    if (_results.length == 0) {
      setState(() {
        _loading = true;
      });
    }

    if (_resultsTimer != null && _resultsTimer.isActive) {
      _resultsTimer.cancel();
    }

    _resultsTimer = new Timer(new Duration(milliseconds: 400), () async {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = true;
      });

      //TODO: debounce widget.results too
      var results = await widget.getResults(_criteria);

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _results = results;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _resultsTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    var results =
        (widget.results ?? _results).where((MaterialSearchResult result) {
      if (widget.filter != null) {
        return widget.filter(result.value, _criteria);
      }
      //only apply default filter if used the `results` option
      //because getResults may already have applied some filter if `filter` option was omited.
      else if (widget.results != null) {
        return _filter(result.value, _criteria);
      }

      return true;
    }).toList();

    if (widget.sort != null) {
      results.sort((a, b) => widget.sort(a.value, b.value, _criteria));
    }

    results = results.take(widget.limit).toList();

    IconThemeData iconTheme =
        Theme.of(context).iconTheme.copyWith(color: widget.iconColor);

    return new Scaffold(
      appBar: new AppBar(
        leading: widget.leading,
        backgroundColor: widget.barBackgroundColor,
        iconTheme: iconTheme,
        title: new TextField(
          controller: _controller,
          autofocus: true,
          decoration:
              new InputDecoration.collapsed(hintText: widget.placeholder),
          style: Theme.of(context).textTheme.headline6,
          onSubmitted: (String value) {
            if (widget.onSubmit != null) {
              widget.onSubmit(value);
            }
          },
        ),
        actions: _criteria.length == 0
            ? []
            : [
                new IconButton(
                    icon: new Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _controller.text = _criteria = '';
                      });
                    }),
              ],
      ),
      body: _loading
          ? new Center(
              child: new Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: new CircularProgressIndicator()),
            )
          : new SingleChildScrollView(
              child: new Column(
                children: results.map((MaterialSearchResult result) {
                  return new InkWell(
                    onTap: () => widget.onSelect(result.value),
                    child: result,
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _MaterialSearchPageRoute<T> extends MaterialPageRoute<T> {
  _MaterialSearchPageRoute({
    @required WidgetBuilder builder,
    RouteSettings settings: const RouteSettings(),
    maintainState: true,
    bool fullscreenDialog: false,
  })  : assert(builder != null),
        super(
            builder: builder,
            settings: settings,
            maintainState: maintainState,
            fullscreenDialog: fullscreenDialog);
}

class MaterialSearchInput<T> extends StatefulWidget {
  MaterialSearchInput({
    Key key,
    this.onSaved,
    this.validator,
    this.autovalidate,
    this.placeholder,
    this.formatter,
    this.results,
    this.getResults,
    this.filter,
    this.sort,
    this.onSelect,
  });

  final FormFieldSetter<T> onSaved;
  final FormFieldValidator<T> validator;
  final bool autovalidate;
  final String placeholder;
  final FormFieldFormatter<T> formatter;

  final List<MaterialSearchResult<T>> results;
  final MaterialResultsFinder getResults;
  final MaterialSearchFilter<T> filter;
  final MaterialSearchSort<T> sort;
  final ValueChanged<T> onSelect;

  @override
  _MaterialSearchInputState<T> createState() =>
      new _MaterialSearchInputState<T>();
}

class _MaterialSearchInputState<T> extends State<MaterialSearchInput<T>> {
  GlobalKey<FormFieldState<T>> _formFieldKey =
      new GlobalKey<FormFieldState<T>>();

  _buildMaterialSearchPage(BuildContext context) {
    return new _MaterialSearchPageRoute<T>(
        settings: new RouteSettings(
          name: 'material_search',
          //isInitialRoute: false,
        ),
        builder: (BuildContext context) {
          return new Material(
            child: new MaterialSearch<T>(
              placeholder: widget.placeholder,
              results: widget.results,
              getResults: widget.getResults,
              filter: widget.filter,
              sort: widget.sort,
              onSelect: (dynamic value) => Navigator.of(context).pop(value),
            ),
          );
        });
  }

  _showMaterialSearch(BuildContext context) {
    Navigator.of(context)
        .push(_buildMaterialSearchPage(context))
        .then((dynamic value) {
      if (value != null) {
        _formFieldKey.currentState.didChange(value);
        widget.onSelect(value);
      }
    });
  }

  bool get autovalidate {
    return widget.autovalidate ??
        Form.of(context)?.widget?.autovalidate ??
        false;
  }

  bool _isEmpty(field) {
    return field.value == null;
  }

  Widget build(BuildContext context) {
    final TextStyle valueStyle = Theme.of(context).textTheme.subtitle1;

    return new InkWell(
      onTap: () => _showMaterialSearch(context),
      child: new FormField<T>(
        key: _formFieldKey,
        validator: widget.validator,
        onSaved: widget.onSaved,
        autovalidate: autovalidate,
        builder: (FormFieldState<T> field) {
          return new InputDecorator(
            baseStyle: valueStyle,
            isEmpty: _isEmpty(field),
            decoration: new InputDecoration(
              labelStyle: _isEmpty(field) ? null : valueStyle,
              labelText: widget.placeholder,
              errorText: field.errorText,
            ),
            child: _isEmpty(field)
                ? null
                : new Text(
                    widget.formatter != null
                        ? widget.formatter(field.value)
                        : field.value.toString(),
                    style: valueStyle),
          );
        },
      ),
    );
  }
}
