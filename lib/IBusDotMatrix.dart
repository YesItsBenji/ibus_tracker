


import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ibus_tracker/IBusControlPanel.dart';
import 'package:ibus_tracker/main.dart';
import 'package:text_scroll/text_scroll.dart';

class DotMatrix extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      
      child: Column(
        
        children: [
          
          _dotMatrixLine(
            dotMatrix: this,

            onBegin: (state){
              IBus.instance.addRefresher(this, () {

                if (state.widget.message != IBus.instance.CurrentMessage){
                  state.setState(() {
                    state.widget.message = IBus.instance.CurrentMessage;
                  });
                }

                print("Refresh Called");

              });
            },

            onUpdate: (state){

            },

            message: "WALTHAMSTOW AVENUE",

          ),
          _dotMatrixLine(
            dotMatrix: this,

            onBegin: (state){

            },

            onUpdate: (state){

              state.setState(() {

                if (IBus.instance.isBusStopping){
                  state.widget.message = "Bus Stopping";
                } else {
                  state.widget.message = getShortTime();
                }

              });

              // print("Updated bottom line");

            },

            message: "",
          )
          
        ],
        
      )
      
    );
  }



}

// Allows each line to refresh independantly

class _dotMatrixLine extends StatefulWidget {

  DotMatrix dotMatrix;

  String message = "";

  Function(_dotMatrixLineState) onBegin;

  Function(_dotMatrixLineState) onUpdate;

  _dotMatrixLine({super.key, required this.dotMatrix, required this.onBegin, required this.onUpdate, this.message = ""});

  @override
  State<_dotMatrixLine> createState() => _dotMatrixLineState();
}

class _dotMatrixLineState extends State<_dotMatrixLine> {

  Color textColor = Colors.orange;

  List<Shadow> textShadow = [
    Shadow(
        blurRadius: 7,
        color: Colors.orange.withOpacity(0.5),
        offset: Offset(0, 0)
    )
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    widget.onBegin(this);

    Timer.periodic(Duration(seconds: 1), (timer) {
      widget.onUpdate(this);
    });

  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      child: TextScroll(
        widget.message,
        // widget.message.length <= 40 ? widget.message : "${widget.message}                                                                           ",
        style: TextStyle(
          fontFamily: "IBus",
          fontSize: 60,
          height: 1,
          color: textColor,
          shadows: textShadow,
        ),
        velocity: Velocity(pixelsPerSecond: Offset(200, 0)),
        intervalSpaces: 75,
      ),
    );
  }
}


