package com.example.demo.domain.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.locationtech.jts.geom.Polygon;

import java.math.BigDecimal;
import java.time.ZonedDateTime;
import java.util.UUID;

@Entity
@Table(name = "parcel_polygons")
@Getter
@Setter
public class ParcelPolygon {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "polygon_id")
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "registration_id", nullable = false, unique = true)
    private LandRegistration registration;

    @Column(name = "boundary_polygon", nullable = false, columnDefinition = "geometry(Polygon,4326)")
    private Polygon boundaryPolygon;

    @Column(name = "centroid_lat", nullable = false, precision = 11, scale = 8)
    private BigDecimal centroidLat;

    @Column(name = "centroid_lng", nullable = false, precision = 11, scale = 8)
    private BigDecimal centroidLng;

    @Column(name = "coordinate_count", nullable = false)
    private int coordinateCount;

    @Column(name = "gps_accuracy_metres", precision = 6, scale = 2)
    private BigDecimal gpsAccuracyMetres;

    @Column(name = "capture_method", nullable = false, length = 20)
    private String captureMethod = "GPS_WALK";

    @Column(name = "is_server_validated", nullable = false)
    private boolean isServerValidated = false;

    @Column(name = "captured_at", nullable = false)
    private ZonedDateTime capturedAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private ZonedDateTime createdAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_user_id", nullable = false)
    private User createdBy;
}
