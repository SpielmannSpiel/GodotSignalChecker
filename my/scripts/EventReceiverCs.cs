using Godot;
using System;

public partial class EventReceiverCs : Node
{
    public void Pressed()
    {
        GD.Print("Pressed CS");
    }

    public void PressedRenamed1()
    {
        GD.Print("Pressed Renamed CS");
    }
}
