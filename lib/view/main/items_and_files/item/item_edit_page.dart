import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mindfulguard/crypto/crypto.dart';
import 'package:mindfulguard/net/api/configuration.dart';
import 'package:mindfulguard/net/api/items/item/update.dart';
import 'package:mindfulguard/view/auth/sign_in_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ItemsEditPage extends StatefulWidget {
  final String apiUrl;
  final String token;
  final String password;
  final String privateKey;
  final Uint8List privateKeyBytes;
  String selectedSafeId;
  String selectedItemId;
  Map<String, dynamic> selectedItemData;

  ItemsEditPage({
    required this.apiUrl,
    required this.token,
    required this.password,
    required this.privateKey,
    required this.privateKeyBytes,
    required this.selectedSafeId,
    required this.selectedItemId,
    required this.selectedItemData,
    Key? key,
  }) : super(key: key);

  @override
  _ItemsEditPageState createState() => _ItemsEditPageState();
}

class _ItemsEditPageState extends State<ItemsEditPage> {
  List<Map<String, dynamic>> sections = [];
  String notes = '';
  final TextEditingController titleController = TextEditingController(text: '');
  String? category;
  final TextEditingController notesController = TextEditingController(text: '');
  List<String> tags = [];
  final TextEditingController tagController = TextEditingController();
  List<String> categoriesApi = [];
  List<String> typesApi = [];

  @override
  void initState() {
    super.initState();

    _fetchApiData();

    // Проверяем, что данные доступны
    if (widget.selectedItemData != null) {
      setState(() {
        titleController.text = widget.selectedItemData['title'];
        category = widget.selectedItemData['category'];
        notesController.text = widget.selectedItemData['notes'];
        tags = List<String>.from(widget.selectedItemData['tags'] ?? []);
        
        // Очищаем и заполняем categoriesApi и typesApi
        categoriesApi.clear();
        typesApi.clear();
        var json = widget.selectedItemData;
        if (json['item_categories'] != null) {
          categoriesApi.addAll(json['item_categories'].map<String>((e) => e.toString()));
        }
        if (json['item_types'] != null) {
          typesApi.addAll(json['item_types'].map<String>((e) => e.toString()));
        }

        // Очищаем и заполняем sections
        sections.clear();
        var sectionsData = widget.selectedItemData['sections'];
        if (sectionsData != null && sectionsData is List) {
          sections.addAll(sectionsData.map<Map<String, dynamic>>((section) {
            var fields = section['fields'];
            if (fields != null && fields is List) {
              return {
                'section': section['section'],
                'fields': List<Map<String, dynamic>>.from(fields),
              };
            }
            return {'section': section['section'], 'fields': []};
          }));
        }
      });
    }
  }

  // Асинхронная функция для загрузки данных с API
  Future<void> _fetchApiData() async {
    var api = await ConfigurationApi(widget.apiUrl).execute();
    if (api?.statusCode != 200) {
      return;
    } else {
      var json = jsonDecode(api!.body);
      
      List<dynamic>? categoriesDynamic = json['item_categories'];
      List<dynamic>? typesDynamic = json['item_types'];

      if (categoriesDynamic != null && typesDynamic != null) {
        setState(() {
          categoriesApi = categoriesDynamic.map((e) => e.toString()).toList();
          typesApi = typesDynamic.map((e) => e.toString()).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editItem),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.title),
              ),
              SizedBox(height: 16),
              Container(
                child: DropdownButtonFormField<String?>(
                  value: category,
                  onChanged: (String? value) {
                    setState(() {
                      category = value!;
                    });
                  },
                  items: categoriesApi
                    .map<DropdownMenuItem<String?>>(
                      (String value) {
                        return DropdownMenuItem<String?>(
                          value: value,
                          child: Text(value),
                        );
                      },
                    ).toList(),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.category,
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.notes),
              ),
              SizedBox(height: 16),
              Wrap(
                children: [
                  for (String tag in tags)
                    TagChip(
                      tag: tag,
                      onEdit: (editedTag) {
                        _editTag(tag, editedTag);
                      },
                      onDelete: () {
                        _deleteTag(tag);
                      },
                    ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _showAddTagDialog,
                    child: Text(AppLocalizations.of(context)!.addTag),
                  ),
                ],
              ),
              SizedBox(height: 16),
              buildSectionsWidget(),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showAddSectionDialog,
                child: Text(AppLocalizations.of(context)!.addSection),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (category == null || typesApi.isEmpty) {
                    // Display a message indicating that both type and category are required
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.categorySelectWarning),
                      ),
                    );
                  } else {
                    saveFormData();
                  }
                },
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSectionsWidget() {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(sections[index]['section']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            _showEditSectionDialog(index);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            _showDeleteSectionDialog(index);
                          },
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: buildFieldsWidgets(index),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _showAddFieldDialog(index);
                    },
                    child: Text(AppLocalizations.of(context)!.addField),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteSectionDialog(int index) {
    // Prevent deletion of the 'init' section
    if (sections[index]['section'] == 'INIT') {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.cannotDeleteItemSection),
            content: Text(AppLocalizations.of(context)!.sectionCannotBeDeleted("INIT")),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.ok),
              ),
            ],
          );
        },
      );
    } else {
      // Allow deletion of other sections
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.deleteSection),
            content: Text(AppLocalizations.of(context)!.deleteSectionWarning),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    sections.removeAt(index);
                  });
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          );
        },
      );
    }
  }

  List<Widget> buildFieldsWidgets(int sectionIndex) {
    List<Widget> widgets = [];
    for (var fieldIndex = 0;
        fieldIndex < sections[sectionIndex]['fields'].length;
        fieldIndex++) {
      widgets.add(
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.8),
                spreadRadius: 1,
                blurRadius: 6.5,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            title: Text('${sections[sectionIndex]['fields'][fieldIndex]['value']}'),
            subtitle: Text(
                '${sections[sectionIndex]['fields'][fieldIndex]['label']} (${sections[sectionIndex]['fields'][fieldIndex]['type']})'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    _showEditFieldDialog(sectionIndex, fieldIndex);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      sections[sectionIndex]['fields'].removeAt(fieldIndex);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  void _showAddSectionDialog() {
    TextEditingController sectionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.addSection),
          content: TextField(
            controller: sectionController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.name),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  sections.add({
                    'section': sectionController.text,
                    'fields': [],
                  });
                });
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.add),
            ),
          ],
        );
      },
    );
  }

  void _showAddFieldDialog(int sectionIndex) {
    TextEditingController labelController = TextEditingController();
    TextEditingController valueController = TextEditingController();
    String? selectedFieldType;
    
    final double dialogHeight = 350;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.addField),
          content: SizedBox(
            height: dialogHeight,
            child: Column(
              children: [
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.fieldLabel),
                ),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.fieldValue),
                ),
                SizedBox(height: 16),
                Container(
                  child: DropdownButtonFormField<String>(
                    value: selectedFieldType,
                    onChanged: (String? value) {
                      setState(() {
                        selectedFieldType = value!;
                      });
                    },
                    items: typesApi
                      .map<DropdownMenuItem<String>>(
                        (String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        },
                      ).toList(),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldType,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                if (selectedFieldType != null) {
                  setState(() {
                    sections[sectionIndex]['fields'].add({
                      'type': selectedFieldType,
                      'label': labelController.text,
                      'value': valueController.text,
                    });
                  });
                  Navigator.pop(context);
                } else {
                  // Display a message indicating that type is required
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.typeSelectWarning),
                    ),
                  );
                }
              },
              child: Text(AppLocalizations.of(context)!.add),
            ),
          ],
        );
      },
    );
  }
  
  void _showEditSectionDialog(int sectionIndex) {
    TextEditingController sectionController =
        TextEditingController(text: sections[sectionIndex]['section']);
    if (sections[sectionIndex]['section'] == 'INIT') {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.cannotEditItemSection),
            content: Text(AppLocalizations.of(context)!.sectionCannotBeEdited("INIT")),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.ok),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.editItemSection),
            content: TextField(
              controller: sectionController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.name),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    sections[sectionIndex]['section'] =
                        sectionController.text;
                  });
                  Navigator.pop(context);
                },
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          );
        },
      );
    }
  }

  void _showEditFieldDialog(int sectionIndex, int fieldIndex) {
    TextEditingController labelController = TextEditingController(
        text: sections[sectionIndex]['fields'][fieldIndex]['label']);
    TextEditingController valueController = TextEditingController(
        text: sections[sectionIndex]['fields'][fieldIndex]['value']);
    String selectedFieldType = sections[sectionIndex]['fields'][fieldIndex]
        ['type'];

    final double dialogHeight = 350;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.editItemField),
          content: SizedBox(
            height: dialogHeight,
            child: Column(
              children: [
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.fieldLabel),
                ),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.fieldValue),
                ),
                SizedBox(height: 16),
                Container(
                  child: DropdownButtonFormField<String>(
                    value: selectedFieldType,
                    onChanged: (String? value) {
                      setState(() {
                        selectedFieldType = value!;
                      });
                    },
                    items: typesApi
                      .map<DropdownMenuItem<String>>(
                        (String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        },
                      ).toList(),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldType,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  sections[sectionIndex]['fields'][fieldIndex] = {
                    'type': selectedFieldType,
                    'label': labelController.text,
                    'value': valueController.text,
                  };
                });
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.addTag),
          content: TextField(
            controller: tagController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.tag),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  tags.add(tagController.text);
                  tagController.clear();
                });
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.add),
            ),
          ],
        );
      },
    );
  }

  void _editTag(String oldTag, String newTag) {
    setState(() {
      tags[tags.indexOf(oldTag)] = newTag;
    });
  }

  void _deleteTag(String tag) {
    setState(() {
      tags.remove(tag);
    });
  }

  Future<Map<String, dynamic>> _encryptFormData(Map<String, dynamic> data) async {
    // Create a deep copy of data
    Map<String, dynamic> result = json.decode(json.encode(data));

    // Encrypt notes
    result['notes'] = await Crypto.crypto().encrypt(result['notes'], widget.password, widget.privateKeyBytes);

    // Check and encrypt fields in sections
    if (result['sections'] != null && result['sections'] is List) {
      List<dynamic> sections = result['sections'];
      for (var i = 0; i < sections.length; i++) {
        if (sections[i] != null && sections[i] is Map<String, dynamic>) {
          Map<String, dynamic> section = sections[i];
          if (section['fields'] != null && section['fields'] is List) {
            List<dynamic> fields = section['fields'];
            for (var j = 0; j < fields.length; j++) {
              if (fields[j] != null && fields[j] is Map<String, dynamic>) {
                // Encrypt the field value
                fields[j]['value'] = await Crypto.crypto().encrypt(
                  fields[j]['value'],
                  widget.password,
                  widget.privateKeyBytes,
                );
              }
            }
          }
        }
      }
    }
    
    // Return the modified result without changing the original data
    return result;
  }

  Future<void> saveFormData() async {
    var formData = {
      'title': titleController.text,
      'category': category,
      'notes': notesController.text,
      'tags': tags,
      'sections': sections,
    };

    var encryptFormData = await _encryptFormData(formData);

    var api = await ItemUpdateApi(
      widget.apiUrl,
      widget.token,
      widget.selectedSafeId,
      widget.selectedItemId,
      encryptFormData,
    ).execute();

    if (api != null && api.statusCode == 401) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInPage()),
      );
    } else {
      // Use Navigator.pop with a result
      Navigator.pop(context, true); // Pass any result you want, e.g., true
    }

    print(api?.statusCode);
  }
}

class TagChip extends StatelessWidget {
  final String tag;
  final Function(String) onEdit;
  final Function onDelete;

  TagChip({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.blue,
            ),
            child: Text(
              tag,
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              _showEditTagDialog(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _showDeleteTagDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showEditTagDialog(BuildContext context) {
    TextEditingController editedTagController = TextEditingController(text: tag);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.editTag),
          content: TextField(
            controller: editedTagController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.tag),
            maxLength: 20,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                onEdit(editedTagController.text);
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.deleteTag),
          content: Text(AppLocalizations.of(context)!.deleteTagWarning),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                onDelete();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        );
      },
    );
  }
}