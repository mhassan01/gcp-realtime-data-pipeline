FROM gcr.io/dataflow-templates-base/python311-template-launcher-base

# Set environment variables
ENV FLEX_TEMPLATE_PYTHON_REQUIREMENTS_FILE="/opt/apache/beam/requirements.txt"
ENV FLEX_TEMPLATE_PYTHON_PY_FILE="/opt/apache/beam/streaming_pipeline.py"

# Copy requirements and install dependencies
COPY requirements.txt /opt/apache/beam/requirements.txt
RUN pip install --no-cache-dir -r /opt/apache/beam/requirements.txt

# Copy pipeline code
COPY streaming_pipeline.py /opt/apache/beam/streaming_pipeline.py

# Setup entrypoint
ENTRYPOINT ["/opt/apache/beam/boot"] 