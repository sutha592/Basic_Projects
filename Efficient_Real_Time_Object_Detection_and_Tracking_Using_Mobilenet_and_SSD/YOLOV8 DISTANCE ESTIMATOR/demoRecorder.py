import cv2 as cv
import numpy as np
import pyttsx3
import torch  # Make sure to import torch

# Initialize text-to-speech engine
engine = pyttsx3.init()

# YOLOv8 model loading using Ultralytics
model = torch.hub.load('ultralytics/yolov8', 'yolov8n', pretrained=True)
class_names = model.names

# Define object dimensions in inches
PERSON_WIDTH = 16  # Example width of a person in inches
MOBILE_WIDTH = 3.0  # Example width of a mobile phone in inches

# Initialize video capture
cap = cv.VideoCapture(0)

# Focal length variables (assumed to be calculated beforehand)
focal_person = 800  # Placeholder value; replace with actual calculated value
focal_mobile = 400  # Placeholder value; replace with actual calculated value

# Main loop for video capture
while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    # Detect objects in the current frame
    results = model(frame)
    announcements = []  # List to store announcements

    for result in results.xyxy[0]:
        class_id = int(result[5])
        confidence = result[4]
        x1, y1, x2, y2 = map(int, result[:4])
        object_width_in_frame = x2 - x1
        object_name = class_names[class_id]

        # Draw bounding box and label
        color = (0, 255, 0)
        cv.rectangle(frame, (x1, y1), (x2, y2), color, 2)
        label = f"{object_name}: {confidence:.2f}"
        cv.putText(frame, label, (x1, y1 - 10), cv.FONT_HERSHEY_COMPLEX, 0.5, color, 2)

        # Distance estimation logic
        distance = None
        if object_name == 'person':
            distance = (PERSON_WIDTH * focal_person) / object_width_in_frame
        elif object_name == 'cell phone':
            distance = (MOBILE_WIDTH * focal_mobile) / object_width_in_frame

        if distance is not None and object_width_in_frame > 0:  # Prevent division by zero
            # Draw the distance on the frame
            cv.putText(frame, f"Distance: {round(distance, 2)} inch", (x1 + 5, y1 + 20), cv.FONT_HERSHEY_COMPLEX, 0.48, (0, 255, 0), 2)

            # Announce detected object and distance
            announcement = f"{object_name} detected at {round(distance, 2)} inches"
            announcements.append(announcement)

    # Process the speech queue after processing all detections
    if announcements:  # Only process if there are announcements
        for announcement in announcements:
            engine.say(announcement)
        engine.runAndWait()

    # Show the video frame
    cv.imshow('YOLOv8 Distance Estimation Demo', frame)

    # Quit with 'q'
    if cv.waitKey(1) & 0xFF == ord('q'):
        break

# Cleanup
cap.release()
cv.destroyAllWindows()
